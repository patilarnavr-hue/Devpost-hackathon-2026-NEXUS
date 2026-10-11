// OllamaService — OpenAI-compatible client for local Ollama (chat + tools)

import Foundation

@MainActor
final class OllamaService: ObservableObject {
    static let shared = OllamaService()

    @Published var isAvailable = false
    @Published var availableModels: [String] = []
    @Published var selectedModel = "llama3.2:3b"

    private let baseURL = "http://127.0.0.1:11434/v1"
    private let session = URLSession.shared

    private init() {
        checkAvailability()
    }

    func checkAvailability() {
        Task { await refreshModels() }
    }

    func refreshModels() async {
        do {
            let url = URL(string: "http://127.0.0.1:11434/api/tags")!
            let (data, _) = try await session.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                let names = models.compactMap { $0["name"] as? String }
                self.availableModels = names
                self.isAvailable = !names.isEmpty
                if self.selectedModel.isEmpty || !names.contains(self.selectedModel) {
                    self.selectedModel = names.first { $0.contains("3b") } ?? names.first ?? "llama3.2:3b"
                }
            }
        } catch {
            self.isAvailable = false
        }
    }

    // MARK: - Simple chat (no tools)

    func chat(messages: [(role: String, content: String)], system: String, temperature: Double = 0.4) async -> String {
        guard isAvailable else {
            return "Ollama not reachable — run ./install.sh and ensure a model is pulled."
        }

        let payload: [String: Any] = [
            "model": selectedModel,
            "stream": false,
            "temperature": temperature,
            "messages": [["role": "system", "content": system]]
                + messages.map { ["role": $0.role, "content": $0.content] }
        ]

        do {
            let url = URL(string: "\(baseURL)/chat/completions")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.timeoutInterval = 300
            req.httpBody = try JSONSerialization.data(withJSONObject: payload)

            let (data, _) = try await session.data(for: req)

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let first = choices.first,
               let msg = first["message"] as? [String: Any],
               let content = msg["content"] as? String {
                return content
            }
            if let raw = String(data: data, encoding: .utf8) {
                return "Ollama error: \(raw.prefix(300))"
            }
        } catch {
            return "Error: \(error.localizedDescription)"
        }
        return "(no response)"
    }

    // MARK: - Chat with tools

    func chatWithTools(
        prompt: String,
        system: String,
        tools: [[String: Any]],
        temperature: Double = 0.3
    ) async -> (content: String, toolCalls: [[String: Any]]) {
        guard isAvailable else {
            return ("Ollama not reachable", [])
        }

        var payload: [String: Any] = [
            "model": selectedModel,
            "stream": false,
            "temperature": temperature,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": prompt]
            ]
        ]
        if !tools.isEmpty {
            payload["tools"] = tools
            payload["tool_choice"] = "auto"
        }

        do {
            let url = URL(string: "\(baseURL)/chat/completions")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.timeoutInterval = 300
            req.httpBody = try JSONSerialization.data(withJSONObject: payload)

            let (data, _) = try await session.data(for: req)

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let first = choices.first,
               let msg = first["message"] as? [String: Any] {
                let content = msg["content"] as? String ?? ""
                let calls = msg["tool_calls"] as? [[String: Any]] ?? []
                return (content, calls)
            }
        } catch {
            return ("Error: \(error.localizedDescription)", [])
        }
        return ("(no response)", [])
    }

    // MARK: - Tools per intent

    func toolsForIntent(_ intent: String) -> [[String: Any]] {
        switch intent {
        case "search", "find":
            return [
                fn("search_files", "Search local files with Spotlight",
                    props: ["query": str("Search terms"), "scope": enumOf("all", "desktop", "documents", "downloads")],
                    required: ["query"]),
                fn("search_web", "Search the web via DuckDuckGo",
                    props: ["query": str("Search query")], required: ["query"]),
                fn("open_file", "Open or reveal a file",
                    props: ["path": str("Full path"), "reveal": bool()], required: ["path"])
            ]
        case "brainstorm":
            return [
                fn("search_web", "Research a topic on the web",
                    props: ["query": str("Search query")], required: ["query"]),
                fn("create_note", "Save a note to Documents/NexusNotes",
                    props: ["title": str("Note title"), "content": str("Markdown content")], required: ["title", "content"])
            ]
        default:
            return [
                fn("run_process", "Run a shell command; returns stdout/stderr/exit code",
                    props: ["command": str("Shell command"), "cwd": str("Working directory")], required: ["command"]),
                fn("read_file", "Read a file",
                    props: ["path": str("File path")], required: ["path"]),
                fn("write_file", "Write a file",
                    props: ["path": str("File path"), "content": str("Contents")], required: ["path", "content"]),
                fn("edit_file", "Replace text in a file",
                    props: ["path": str("File path"), "old_text": str("Text to replace"), "new_text": str("Replacement")],
                    required: ["path", "old_text", "new_text"]),
                fn("list_directory", "List a directory",
                    props: ["path": str("Directory")], required: ["path"]),
                fn("run_verifier", "Run FixtureTests and return the real exit code (0 = pass)",
                    props: [:], required: [])
            ]
        }
    }

    func systemPrompt(for intent: String) -> String {
        switch intent {
        case "search", "find":
            return "You are NEXUS search. Use tools to find files or web info, then summarise concisely."
        case "brainstorm":
            return "You are NEXUS brainstorm partner. Generate ideas, research with tools, structure as lists."
        case "mission", "steer":
            return "You are NEXUS mission controller. Plan, act with tools, verify with run_verifier, report exit codes."
        case "direct":
            return "You are NEXUS direct executor. Run exactly what is asked and report the result."
        default:
            return "You are NEXUS, a local autonomous assistant."
        }
    }

    // MARK: - Tool schema helpers

    private func fn(_ name: String, _ desc: String, props: [String: Any], required: [String]) -> [String: Any] {
        ["type": "function", "function": ["name": name, "description": desc,
                                           "parameters": ["type": "object", "properties": props, "required": required]]]
    }

    private func str(_ d: String) -> [String: Any] { ["type": "string", "description": d] }
    private func bool() -> [String: Any] { ["type": "boolean"] }
    private func enumOf(_ values: String...) -> [String: Any] { ["type": "string", "enum": values] }
}