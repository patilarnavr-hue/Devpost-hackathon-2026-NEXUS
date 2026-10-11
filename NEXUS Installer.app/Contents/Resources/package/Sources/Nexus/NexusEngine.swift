// NEXUS Engine — fully local with Ollama (no WebSocket dependency)

import Foundation
import Combine
import AppKit

@MainActor
final class NexusEngine: NSObject, ObservableObject {
    static let shared = NexusEngine()

    @Published var state: MachineState = .idle
    @Published var objective: String = ""
    @Published var currentTask: String = "Standing by"
    @Published var detail: String = "No active operation"
    @Published var progress: Double = 0
    @Published var verification: VerificationStatus = .notRun
    @Published var activeTool: String = "—"
    @Published var modelName: String = "llama3.2:3b"
    @Published var modelProvider: String = "ollama_local"
    @Published var events: [ActivityEvent] = []
    @Published var plan: PlanData?
    @Published var memories: [MemoryItem] = []
    @Published var isConnected: Bool = true
    @Published var connectionStatus: String = "Local (Ollama)"
    @Published var currentStep: Int = 0
    @Published var totalSteps: Int = 0
    @Published var workflowName: String = ""
    @Published var lastError: String = ""
    @Published var sourcesFound: Int = 0
    @Published var filesCreated: Int = 0

    @Published var sessions: [SessionSummary] = []
    @Published var activeSession: SessionInfo?
    @Published var briefing: SessionBriefing?
    @Published var worldTransition: WorldTransition?
    @Published var arbitration: ArbitrationData?
    @Published var arbitrationAt: Date = Date()
    @Published var mission: MissionData?
    @Published var dashboard: DashboardData?

    /// A mission is live while the pipeline is between idle/success/error.
    var missionRunning: Bool {
        ![MachineState.idle, .success, .error].contains(state)
    }

    private let ollama = OllamaService.shared
    private let executor = Executor.shared
    private let verifier = Verifier.self

    private override init() {
        super.init()
        // Start in local mode - no WebSocket needed
        isConnected = true
        connectionStatus = "Local (Ollama)"
        // Load available models
        Task { await ollama.refreshModels() }
        // Create initial empty session
        createSession()
        // Live tail of the Red Triangle's bridge stream
        startBridgeTail()
    }

    // MARK: - Triangle bridge (live automation feed)

    private var bridgeOffset: UInt64 = 0
    private var bridgeTimer: Timer?

    private var bridgeFile: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Nexus/bridge.jsonl")
    }

    private func startBridgeTail() {
        // start at EOF so we only show new activity
        if let attrs = try? FileManager.default.attributesOfItem(atPath: bridgeFile.path),
           let size = attrs[.size] as? UInt64 {
            bridgeOffset = size
        }
        let t = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.drainBridge() }
        }
        RunLoop.main.add(t, forMode: .common)
        bridgeTimer = t
    }

    private func drainBridge() {
        guard let handle = try? FileHandle(forReadingFrom: bridgeFile) else { return }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        guard size > bridgeOffset else { return }
        try? handle.seek(toOffset: bridgeOffset)
        guard let data = try? handle.readToEnd(), !data.isEmpty else { return }
        bridgeOffset = size
        guard let text = String(data: data, encoding: .utf8) else { return }
        for line in text.split(separator: "\n") {
            guard let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  let kind = obj["kind"] as? String,
                  let msg = obj["text"] as? String else { continue }
            let ts = (obj["ts"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? Date()
            let sev = kind.contains("fail") || kind == "blocked" ? "warning" : "info"
            addEvent(ActivityEvent(type: "triangle_\(kind)", message: msg, timestamp: ts, severity: sev))
        }
    }

    private func playTransition(_ t: WorldTransition) {
        worldTransition = t
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) { [weak self] in
            self?.worldTransition = nil
        }
    }

    func createSession(name: String = "") {
        let label = name.isEmpty ? "NEW SESSION" : name
        playTransition(WorldTransition(
            start: Date(),
            from: activeSession?.name ?? "",
            to: label))
        // Clear local session immediately so chat doesn't show old data
        activeSession = nil
        sessions = []
        briefing = nil
        // Create empty local session
        let newSession = SessionInfo(
            id: UUID().uuidString,
            name: label,
            objective: "",
            state: "IDLE",
            workflow: "",
            decisions: [],
            timeline: []
        )
        activeSession = newSession
        sessions = [SessionSummary(from: ["id": newSession.id, "name": label, "objective": "", "state": "IDLE", "workflow": "", "timeline_count": 0, "active": true, "updated_at": Date().timeIntervalSince1970])]
        // Notify UI
        objective = ""
        currentTask = "New session ready"
        detail = "Enter a goal to begin"
        state = .idle
        addEvent(ActivityEvent(type: "session_created", message: "New session: \(label)", timestamp: Date()))
    }

    func switchSession(_ id: String) {
        guard id != activeSession?.id else { return }
        if let session = sessions.first(where: { $0.id == id }) {
            activeSession = SessionInfo(from: [
                "id": session.id, "name": session.name, "objective": session.objective,
                "state": session.state, "workflow": session.workflow,
                "decisions": [], "timeline": []
            ])
            objective = session.objective
            playTransition(WorldTransition(start: Date(), from: activeSession?.name ?? "", to: session.name))
            addEvent(ActivityEvent(type: "session_switch", message: "Switched to: \(session.name)", timestamp: Date()))
        }
    }

    func sendGoal(_ text: String, intent: String = "mission", template: String? = nil, dryRun: Bool = false) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        state = .analyzing
        currentTask = "Processing: \(text.prefix(50))"
        objective = text
        
        // Update active session
        if activeSession == nil { createSession() }
        activeSession = SessionInfo(from: [
            "id": activeSession?.id ?? UUID().uuidString,
            "name": activeSession?.name ?? "SESSION",
            "objective": text,
            "state": state.rawValue,
            "workflow": workflowName,
            "decisions": [],
            "timeline": (activeSession?.timeline ?? []) + [
                ["t": Date().timeIntervalSince1970, "kind": "goal", "label": text, "severity": "info", "role": "user"]
            ]
        ])

        // Process via Ollama based on intent
        Task { await processViaOllama(text: text, intent: intent) }
    }

    func sendControl(_ action: String, note: String = "") {
        currentTask = "Control: \(action)"
        addEvent(ActivityEvent(type: "control", message: "\(action) \(note)", timestamp: Date()))
        
        switch action {
        case "pause":
            state = .idle
            currentTask = "Paused"
        case "stop":
            state = .idle
            currentTask = "Stopped"
            objective = ""
        default:
            break
        }
    }

    func requestState() {
        // Local state is always current
    }

    func requestSessions() {
        // Sessions are local
    }

    func requestDashboard() {
        dashboard = DashboardData(from: [:])
    }

    func resolvePendingSwitch(action: SessionSwitchPref, remember: Bool) {
        // Handled locally
    }

    func cancelPendingSwitch() {
        AppState.shared.pendingSwitch = nil
    }

    func sendApprovalResponse(approvalId: String, action: String, args: String = "") {
        // Handled locally
    }

    // MARK: - Ollama Processing

    private func processViaOllama(text: String, intent: String) async {
        await ollama.refreshModels()
        guard ollama.isAvailable else {
            await MainActor.run {
                self.state = .error
                self.lastError = "Ollama not available"
                self.currentTask = "Ollama unavailable"
            }
            return
        }

        await MainActor.run {
            self.state = .planning
            self.modelName = ollama.selectedModel
        }

        let systemPrompt = ollama.systemPrompt(for: intent)
        let tools = ollama.toolsForIntent(intent)
        let result = await ollama.chatWithTools(
            prompt: text,
            system: systemPrompt,
            tools: tools,
            temperature: intent == "brainstorm" ? 0.7 : 0.3
        )
        let content = result.content
        let toolCalls = result.toolCalls

        // Execute tool calls
        if !toolCalls.isEmpty {
            for call in toolCalls {
                await executeToolCall(call)
            }
        }

        await MainActor.run {
            if !content.isEmpty {
                self.detail = content
                self.addEvent(ActivityEvent(type: "ollama_response", message: content, timestamp: Date()))
                // Add to chat timeline
                if self.activeSession != nil {
                    var timeline = self.activeSession?.timeline ?? []
                    timeline.append(SessionEntry(from: [
                        "t": Date().timeIntervalSince1970,
                        "kind": "chat",
                        "label": content,
                        "severity": "info",
                        "role": "nexus"
                    ], index: timeline.count))
                    self.activeSession?.timeline = timeline
                }
            }
            if self.state != .error {
                self.state = .success
            }
            self.currentTask = "Ready"
        }
    }

    private func executeToolCall(_ call: [String: Any]) async {
        guard let name = call["name"] as? String,
              let args = call["arguments"] as? [String: Any] else { return }

        await MainActor.run { self.activeTool = name }

        switch name {
        case "read_file":
            if let path = args["path"] as? String {
                let result = await executor.readFile(path: path)
                if result.success {
                    self.addEvent(ActivityEvent(type: "file_read", message: "Read \(path) (\(result.content?.count ?? 0) chars)", timestamp: Date()))
                } else {
                    self.addEvent(ActivityEvent(type: "error", message: "Read failed: \(result.error ?? "unknown")", timestamp: Date()))
                }
            }
        case "write_file":
            if let path = args["path"] as? String, let content = args["content"] as? String {
                let result = await executor.writeFile(path: path, content: content)
                if result.success {
                    self.filesCreated += 1
                    self.addEvent(ActivityEvent(type: "file_write", message: "Wrote \(path)", timestamp: Date()))
                } else {
                    self.addEvent(ActivityEvent(type: "error", message: "Write failed: \(result.error ?? "unknown")", timestamp: Date()))
                }
            }
        case "edit_file":
            if let path = args["path"] as? String, let oldText = args["old_text"] as? String, let newText = args["new_text"] as? String {
                let result = await executor.editFile(path: path, oldText: oldText, newText: newText)
                if result.success {
                    self.addEvent(ActivityEvent(type: "file_edit", message: "Edited \(path)", timestamp: Date()))
                } else {
                    self.addEvent(ActivityEvent(type: "error", message: "Edit failed: \(result.error ?? "unknown")", timestamp: Date()))
                }
            }
        case "list_directory":
            if let path = args["path"] as? String {
                let result = await executor.listDirectory(path: path)
                if result.success {
                    self.sourcesFound = result.content?.components(separatedBy: "\n").count ?? 0
                    self.addEvent(ActivityEvent(type: "dir_list", message: "Listed \(path)", timestamp: Date()))
                } else {
                    self.addEvent(ActivityEvent(type: "error", message: "List failed: \(result.error ?? "unknown")", timestamp: Date()))
                }
            }
        case "run_process":
            if let command = args["command"] as? String {
                let cwd = args["cwd"] as? String
                let result = await executor.runProcess(command: command, cwd: cwd)
                self.addEvent(ActivityEvent(type: "process", message: "Exit \(result.exitCode): \(command)", timestamp: Date()))
            }
        case "run_verifier":
            // Run the fixture test suite and capture exit code
            let result = await Verifier.runAndLog()
            self.verification = result.success ? .passed : .failed
            if result.success {
                self.state = .success
            } else {
                self.state = .error
            }
            self.currentTask = result.success ? "Verification passed" : "Verification failed"
            self.addEvent(ActivityEvent(type: "verification", message: "Exit \(result.exitCode)", timestamp: Date()))
        default:
            // Fall back to built-in implementations
            switch name {
            case "search_files":
                if let query = args["query"] as? String {
                    await searchFiles(scope: args["scope"] as? String ?? "all", query: query)
                }
            case "search_web":
                if let query = args["query"] as? String {
                    await searchWeb(query: query)
                }
            case "open_file":
                if let path = args["path"] as? String {
                    openFile(path: path, reveal: args["reveal"] as? Bool ?? false)
                }
            case "run_process":
                if let command = args["command"] as? String {
                    let cwd = args["cwd"] as? String
                    await runProcess(command: command, cwd: cwd)
                }
            case "read_file":
                if let path = args["path"] as? String {
                    await readFile(path: path)
                }
            case "write_file":
                if let path = args["path"] as? String, let content = args["content"] as? String {
                    await writeFile(path: path, content: content)
                }
            case "create_note":
                if let title = args["title"] as? String, let content = args["content"] as? String {
                    await createNote(title: title, content: content)
                }
            default:
                break
            }
        }

        await MainActor.run { self.activeTool = "—" }
    }

    // MARK: - Tool Implementations

    private func searchFiles(scope: String, query: String) async {
        await MainActor.run { self.currentTask = "Searching files: \(query)" }
        let scopePath: String
        switch scope {
        case "desktop": scopePath = "~/Desktop"
        case "documents": scopePath = "~/Documents"
        case "downloads": scopePath = "~/Downloads"
        default: scopePath = "~"
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["-onlyin", scopePath, query]
        let pipe = Pipe()
        process.standardOutput = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let lines = output.split(separator: "\n").prefix(20).map(String.init)
            await MainActor.run {
                self.sourcesFound = lines.count
                self.addEvent(ActivityEvent(type: "search_result", message: "Found \(lines.count) files for '\(query)'", timestamp: Date()))
            }
        } catch {
            await MainActor.run { self.addEvent(ActivityEvent(type: "error", message: "Search failed: \(error)", timestamp: Date())) }
        }
    }

    private func searchWeb(query: String) async {
        await MainActor.run { self.currentTask = "Searching web: \(query)" }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://html.duckduckgo.com/html/?q=\(encoded)"
        guard let url = URL(string: urlString) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let html = String(data: data, encoding: .utf8) ?? ""
            let snippets = html.components(separatedBy: "result__snippet")
                .dropFirst()
                .prefix(5)
                .compactMap { $0.components(separatedBy: ">").dropFirst().first?.components(separatedBy: "<").first }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            await MainActor.run {
                self.addEvent(ActivityEvent(type: "web_search", message: "Web results for '\(query)': \(snippets.joined(separator: "; "))", timestamp: Date()))
            }
        } catch {
            await MainActor.run { self.addEvent(ActivityEvent(type: "error", message: "Web search failed: \(error)", timestamp: Date())) }
        }
    }

    private func openFile(path: String, reveal: Bool) {
        let url = URL(fileURLWithPath: path)
        if reveal {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.open(url)
        }
        addEvent(ActivityEvent(type: reveal ? "reveal" : "open", message: "File: \(path)", timestamp: Date()))
    }

    private func runProcess(command: String, cwd: String?) async {
        await MainActor.run { self.currentTask = "Running: \(command)" }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        if let cwd = cwd { process.currentDirectoryURL = URL(fileURLWithPath: cwd) }
        let outPipe = Pipe(), errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        do {
            try process.run()
            process.waitUntilExit()
            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outData, encoding: .utf8) ?? ""
            let error = String(data: errData, encoding: .utf8) ?? ""
            await MainActor.run {
                self.addEvent(ActivityEvent(type: "process", message: "Exit \(process.terminationStatus): \(command)\n\(output)\n\(error)", timestamp: Date()))
            }
        } catch {
            await MainActor.run { self.addEvent(ActivityEvent(type: "error", message: "Process failed: \(error)", timestamp: Date())) }
        }
    }

    private func readFile(path: String) async {
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            await MainActor.run { self.addEvent(ActivityEvent(type: "file_read", message: "Read \(path) (\(content.count) chars)", timestamp: Date())) }
        } catch {
            await MainActor.run { self.addEvent(ActivityEvent(type: "error", message: "Read failed: \(error)", timestamp: Date())) }
        }
    }

    private func writeFile(path: String, content: String) async {
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            await MainActor.run {
                self.filesCreated += 1
                self.addEvent(ActivityEvent(type: "file_write", message: "Wrote \(path) (\(content.count) chars)", timestamp: Date()))
            }
        } catch {
            await MainActor.run { self.addEvent(ActivityEvent(type: "error", message: "Write failed: \(error)", timestamp: Date())) }
        }
    }

    private func createNote(title: String, content: String) async {
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let noteURL = docsURL.appendingPathComponent("NexusNotes/\(title).md")
        try? FileManager.default.createDirectory(at: noteURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        await writeFile(path: noteURL.path, content: content)
        await MainActor.run { self.addEvent(ActivityEvent(type: "note_created", message: "Note: \(title)", timestamp: Date())) }
    }

    // MARK: - Event System

    private func addEvent(_ event: ActivityEvent) {
        events.append(event)
        if events.count > 200 { events.removeFirst(events.count - 200) }
    }
}