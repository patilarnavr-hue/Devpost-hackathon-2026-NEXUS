// NexusIdentity — each copy of NEXUS gets its own on-disk identity.
// Data root:  ~/Library/Application Support/Nexus/copies/<copyID>/
// Identity file lives INSIDE the copy's folder as `.nexus-copy` so duplicating
// the folder to another Mac carries its own chat history + memory.

import Foundation

@MainActor
final class NexusIdentity: ObservableObject {
    static let shared = NexusIdentity()

    struct Info: Codable {
        let id: String
        var name: String
        let createdAt: Date
        var rootPath: String
    }

    @Published private(set) var info: Info
    @Published private(set) var root: URL
    @Published private(set) var chatsURL: URL
    @Published private(set) var memoryURL: URL
    @Published private(set) var logsURL: URL

    private static let marker = ".nexus-copy"
    private static let registryName = "copies.json"

    private init() {
        let (markerURL, copyFolder) = NexusIdentity.resolveRoot()

        var loaded: Info
        if let data = try? Data(contentsOf: markerURL),
           let decoded = try? JSONDecoder.iso.decode(Info.self, from: data) {
            loaded = decoded
            loaded.rootPath = copyFolder.path
        } else {
            loaded = Info(
                id: UUID().uuidString,
                name: NexusIdentity.defaultName(for: copyFolder),
                createdAt: Date(),
                rootPath: copyFolder.path
            )
            try? FileManager.default.createDirectory(
                at: markerURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? JSONEncoder.iso.encode(loaded).write(to: markerURL, options: .atomic)
        }

        self.info = loaded
        let dataRoot = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Nexus/copies/\(loaded.id)", isDirectory: true)
        self.root = dataRoot

        self.chatsURL = dataRoot.appendingPathComponent("chats", isDirectory: true)
        self.memoryURL = dataRoot.appendingPathComponent("memory", isDirectory: true)
        self.logsURL = dataRoot.appendingPathComponent("logs", isDirectory: true)

        makeDirectories()
        registerInRegistry()
        AppLifecycle.log("identity copy=\(info.id) name='\(info.name)' marker=\(markerURL.path) data=\(root.path)")
    }

    // MARK: - Public API

    func rename(_ newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        info.name = trimmed
        save()
        registerInRegistry()
    }

    var shortID: String {
        String(info.id.prefix(8))
    }

    /// Where the identity file lives (visible in the copy's folder)
    var markerPath: String { info.rootPath + "/" + NexusIdentity.marker }

    // MARK: - Internals

    private func makeDirectories() {
        for dir in [chatsURL, memoryURL, logsURL] {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    private func save() {
        guard let markerURL = NexusIdentity.markerIfPresent() else { return }
        info.rootPath = markerURL.deletingLastPathComponent().path
        try? JSONEncoder.iso.encode(info).write(to: markerURL, options: .atomic)
    }

    private func registerInRegistry() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let registryURL = support.appendingPathComponent("Nexus/\(NexusIdentity.registryName)")

        var registry: [String: [String: Any]] = [:]
        if let data = try? Data(contentsOf: registryURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] {
            registry = json
        }

        let fm = FileManager.default
        var chatCount = 0
        if let files = try? fm.contentsOfDirectory(at: chatsURL, includingPropertiesForKeys: nil) {
            chatCount = files.filter { $0.pathExtension == "json" && $0.lastPathComponent != "index.json" }.count
        }

        registry[info.id] = [
            "name": info.name,
            "root": info.rootPath,
            "lastSeen": ISO8601DateFormatter().string(from: Date()),
            "chatCount": chatCount
        ]

        try? fm.createDirectory(at: registryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONSerialization.data(withJSONObject: registry, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: registryURL, options: .atomic)
        }
    }

    private static func markerIfPresent() -> URL? {
        let (url, _) = resolveRoot()
        return url
    }

    // MARK: - Root resolution

    /// Returns (markerURL, rootFolder). The root is the copy's folder.
    static func resolveRoot() -> (URL, URL) {
        let fm = FileManager.default
        var candidates: [URL] = []

        if let override = ProcessInfo.processInfo.environment["NEXUS_REPO"] {
            candidates.append(URL(fileURLWithPath: override))
        }

        var cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        for _ in 0..<5 {
            candidates.append(cwd)
            cwd = cwd.deletingLastPathComponent()
        }

        var bundle = Bundle.main.bundleURL
        for _ in 0..<5 {
            candidates.append(bundle)
            bundle = bundle.deletingLastPathComponent()
        }

        for folder in candidates {
            if looksLikeRoot(folder) { return (folder.appendingPathComponent(marker), folder) }
        }
        // Fallback: a sandbox root under Application Support
        let fallback = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Nexus/standalone-root", isDirectory: true)
        return (fallback.appendingPathComponent(marker), fallback)
    }

    private static func looksLikeRoot(_ url: URL) -> Bool {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.appendingPathComponent("Package.swift").path) { return true }
        if fm.fileExists(atPath: url.appendingPathComponent("Sources").path) { return true }
        if fm.fileExists(atPath: url.appendingPathComponent(marker).path) { return true }
        // Hackathon submission folder: holds Nexus/ + FixturePackage/ + install.sh
        if fm.fileExists(atPath: url.appendingPathComponent("FixturePackage").path) { return true }
        if fm.fileExists(atPath: url.appendingPathComponent("Nexus").path),
           fm.fileExists(atPath: url.appendingPathComponent("install.sh").path) { return true }
        if fm.fileExists(atPath: url.appendingPathComponent("Nexus").path),
           fm.fileExists(atPath: url.appendingPathComponent("README.md").path) { return true }
        return false
    }

    private static func defaultName(for folder: URL) -> String {
        let folderName = folder.lastPathComponent
        let cleaned = folderName
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return "Nexus Copy" }

        let words = cleaned
            .split(separator: " ")
            .filter { !$0.isEmpty }
            .prefix(3)
            .map { $0.capitalized }
        guard !words.isEmpty else { return "Nexus Copy" }
        return "Nexus · " + words.joined(separator: " ")
    }
}

// MARK: - ISO8601 JSON helpers

enum JSONCoder {
    static let iso: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    static let isoDec: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

extension JSONEncoder {
    static var iso: JSONEncoder { JSONCoder.iso }
}

extension JSONDecoder {
    static var iso: JSONDecoder { JSONCoder.isoDec }
}