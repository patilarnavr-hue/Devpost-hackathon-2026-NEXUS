// MemoryStore — persistent, per-copy memory. Survives restarts, isolated per copy.

import Foundation

@MainActor
final class MemoryStore: ObservableObject {
    static let shared = MemoryStore()

    struct Entry: Identifiable, Equatable, Codable {
        var id: String = UUID().uuidString
        var content: String
        var tags: [String] = []
        var source: String          // "chat", "manual", "file"
        var createdAt: Date = Date()
        var pinned: Bool = false
    }

    @Published private(set) var entries: [Entry] = []
    @Published var query: String = ""

    private let identity = NexusIdentity.shared
    private var fileURL: URL { identity.memoryURL.appendingPathComponent("memories.json") }

    var filtered: [Entry] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return entries }
        let q = query.lowercased()
        return entries.filter {
            $0.content.lowercased().contains(q) || $0.tags.contains { $0.lowercased().contains(q) }
        }
    }

    var count: Int { entries.count }

    private init() {
        load()
    }

    // MARK: - CRUD

    @discardableResult
    func add(_ content: String, tags: [String] = [], source: String = "manual", pinned: Bool = false) -> Entry {
        let entry = Entry(
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: tags,
            source: source,
            pinned: pinned
        )
        entries.insert(entry, at: 0)
        save()
        return entry
    }

    func update(_ id: String, content: String, tags: [String]) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[i].content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        entries[i].tags = tags
        save()
    }

    func togglePin(_ id: String) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[i].pinned.toggle()
        save()
    }

    func delete(_ id: String) {
        entries.removeAll { $0.id == id }
        save()
    }

    func clearAll() {
        entries.removeAll()
        save()
    }

    /// Parses "#tag" tokens out of content and returns (cleanContent, tags)
    static func parseTags(from text: String) -> (String, [String]) {
        var tags: [String] = []
        var kept: [String] = []
        for token in text.split(separator: " ") {
            let word = String(token)
            if word.hasPrefix("#") && word.count > 1 {
                tags.append(String(word.dropFirst()).lowercased())
            } else {
                kept.append(word)
            }
        }
        return (kept.joined(separator: " "), tags)
    }

    func export() -> String {
        (entries.map { "- (\($0.source)) \($0.content) \($0.tags.isEmpty ? "" : "[\($0.tags.joined(separator: ", "))]")" })
            .joined(separator: "\n")
    }

    var statLine: String {
        let pinned = entries.filter { $0.pinned }.count
        let bytes = (try? Data(contentsOf: fileURL).count) ?? 0
        return "\(entries.count) entries · \(pinned) pinned · \(bytes.formatted(.byteCount(style: .file)))"
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder.iso.decode([Entry].self, from: data) else { return }
        entries = decoded.sorted {
            $0.pinned != $1.pinned ? $0.pinned && !$1.pinned : $0.createdAt > $1.createdAt
        }
    }

    private func save() {
        entries.sort {
            $0.pinned != $1.pinned ? $0.pinned && !$1.pinned : $0.createdAt > $1.createdAt
        }
        try? FileManager.default.createDirectory(at: identity.memoryURL, withIntermediateDirectories: true)
        try? JSONEncoder.iso.encode(entries).write(to: fileURL, options: .atomic)
    }
}