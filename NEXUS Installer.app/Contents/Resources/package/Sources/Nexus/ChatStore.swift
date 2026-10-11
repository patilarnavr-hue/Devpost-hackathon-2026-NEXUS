// ChatStore — persistent, per-copy chat sessions.
// Every copy of NEXUS has its own identity (see NexusIdentity), so chat
// history and memory never leak between copies.

import Foundation

@MainActor
final class ChatStore: ObservableObject {
    static let shared = ChatStore()

    // MARK: - Model

    struct Message: Identifiable, Equatable, Codable {
        var id: String = UUID().uuidString
        var role: Role
        var content: String
        var timestamp: Date = Date()
        var mode: Mode

        enum Role: String, Codable, Equatable { case user, nexus }
        enum Mode: String, Codable, CaseIterable { case mission, brainstorm, search, direct }
    }

    struct ChatSession: Identifiable, Equatable, Codable {
        var id: String = UUID().uuidString
        var title: String
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        var messages: [Message] = []
    }

    // MARK: - State

    @Published private(set) var sessions: [ChatSession] = []
    @Published private(set) var activeID: String?
    @Published var isThinking = false
    @Published var selectedMode: Message.Mode = .mission
    @Published var lastError: String?

    var activeSession: ChatSession? {
        sessions.first { $0.id == activeID }
    }

    var messages: [Message] {
        activeSession?.messages ?? []
    }

    // MARK: - Storage

    private let identity = NexusIdentity.shared
    private let fm = FileManager.default
    private let ollama = OllamaService.shared
    private var indexURL: URL { identity.chatsURL.appendingPathComponent("index.json") }

    var dataDirectory: String { identity.chatsURL.path }

    private init() {
        loadIndex()
        if sessions.isEmpty { newChat() }
    }

    // MARK: - Sessions

    func newChat() {
        flushActiveSession()
        let session = ChatSession(title: "New chat")
        sessions.insert(session, at: 0)
        activeID = session.id
        saveIndex()
    }

    func selectChat(_ id: String) {
        guard id != activeID else { return }
        flushActiveSession()
        activeID = id
        saveIndex()
    }

    func renameChat(_ id: String, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let i = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[i].title = trimmed
        sessions[i].updatedAt = Date()
        saveIndex()
        writeSession(sessions[i])
    }

    func deleteChat(_ id: String) {
        sessions.removeAll { $0.id == id }
        try? fm.removeItem(at: sessionFileURL(id))
        if activeID == id {
            activeID = sessions.first?.id
            if sessions.isEmpty { newChat() }
        }
        saveIndex()
    }

    /// Wipe every chat in this copy (memory is untouched)
    func clearAllChats() {
        sessions.removeAll()
        if let files = try? fm.contentsOfDirectory(at: identity.chatsURL, includingPropertiesForKeys: nil) {
            for f in files where f.pathExtension == "json" {
                try? fm.removeItem(at: f)
            }
        }
        newChat()
    }

    // MARK: - Messaging

    func send(_ text: String, mode: Message.Mode? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let useMode = mode ?? selectedMode
        guard var session = activeSession else { newChat(); return }

        if session.title == "New chat" {
            session.title = ChatStore.deriveTitle(from: trimmed)
        }
        session.messages.append(Message(role: .user, content: trimmed, mode: useMode))
        session.updatedAt = Date()
        commit(session)

        persist(session)
        respond(sessionID: session.id, mode: useMode)
    }

    func stopThinking() {
        isThinking = false
        if var session = activeSession {
            session.messages.append(Message(role: .nexus, content: "⏹ Stopped by user.", mode: .direct))
            session.updatedAt = Date()
            commit(session)
            persist(session)
        }
    }

    private func respond(sessionID: String, mode: Message.Mode) {
        isThinking = true
        lastError = nil

        let history = (sessions.first { $0.id == sessionID }?.messages ?? [])
            .suffix(12)
            .map { (role: $0.role == .user ? "user" : "assistant", content: $0.content) }

        Task {
            let reply = await ollama.chat(
                messages: history,
                system: ChatStore.systemPrompt(for: mode)
            )
            await MainActor.run {
                self.isThinking = false
                guard var session = self.sessions.first(where: { $0.id == sessionID }) else { return }
                session.messages.append(Message(role: .nexus, content: reply, mode: mode))
                session.updatedAt = Date()
                self.commit(session)
                self.persist(session)
                self.saveIndex()
            }
        }
    }

    // MARK: - Persistence helpers

    private func commit(_ session: ChatSession) {
        if let i = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[i] = session
        } else {
            sessions.insert(session, at: 0)
        }
    }

    private func flushActiveSession() {
        if let s = activeSession, !s.messages.isEmpty { writeSession(s) }
    }

    private func persist(_ session: ChatSession) {
        writeSession(session)
        saveIndex()
    }

    private func writeSession(_ session: ChatSession) {
        try? JSONEncoder.iso.encode(session).write(to: sessionFileURL(session.id), options: .atomic)
    }

    private func sessionFileURL(_ id: String) -> URL {
        identity.chatsURL.appendingPathComponent("\(id).json")
    }

    private func loadIndex() {
        // Session files are the source of truth; index.json is lightweight metadata for
        // humans/debugging. Anything orphaned still gets picked up.
        var loaded: [ChatSession] = []
        if let files = try? fm.contentsOfDirectory(at: identity.chatsURL, includingPropertiesForKeys: nil) {
            for f in files where f.pathExtension == "json" && f.lastPathComponent != "index.json" {
                guard let data = try? Data(contentsOf: f),
                      let s = try? JSONDecoder.iso.decode(ChatSession.self, from: data) else { continue }
                loaded.append(s)
            }
        }

        sessions = loaded.sorted { $0.updatedAt > $1.updatedAt }
        activeID = sessions.first?.id
        saveIndex()
    }

    private func saveIndex() {
        let summaries = sessions.map { ["id": $0.id, "title": $0.title,
                                        "updatedAt": ISO8601DateFormatter().string(from: $0.updatedAt),
                                        "messageCount": $0.messages.count] }
        if let data = try? JSONSerialization.data(withJSONObject: summaries, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: indexURL, options: .atomic)
        }
    }

    // MARK: - Titles & prompts

    static func deriveTitle(from text: String) -> String {
        let clean = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.count <= 42 { return clean.isEmpty ? "New chat" : clean }
        let cut = clean.prefix(42)
        if let space = cut.lastIndex(of: " ") {
            return String(cut[..<space]) + "…"
        }
        return String(cut) + "…"
    }

    static func systemPrompt(for mode: Message.Mode) -> String {
        switch mode {
        case .mission:
            return """
            You are NEXUS, a local autonomous coding agent. Break the user's task into
            concrete steps, act mentally, and describe results concisely. Say what exit
            code or command would prove success before claiming a task is done.
            """
        case .brainstorm:
            return """
            You are NEXUS, a creative brainstorming partner. Generate ideas, explore
            angles, ask one clarifying question if needed, and structure output as lists.
            Be imaginative but practical.
            """
        case .search:
            return """
            You are NEXUS search assistant. Answer concisely. The query concerns local
            files, web information, or system state. If you don't know, say so plainly.
            """
        case .direct:
            return """
            You are NEXUS direct executor. Do exactly what is asked. Return the result,
            command, or output with no commentary.
            """
        }
    }
}