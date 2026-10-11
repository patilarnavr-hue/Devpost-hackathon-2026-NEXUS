// NexusInstaller — professional setup wizard for NEXUS (EvoHacks 2026)
// Steps: Welcome → Settings → Install → Done

import SwiftUI

@main
struct InstallerApp: App {
    @NSApplicationDelegateAdaptor(InstallerAppDelegate.self) private var delegate
    var body: some Scene {
        WindowGroup {
            InstallerView()
                .frame(width: 720, height: 520)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 720, height: 520)
    }
}

final class InstallerAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }
}

// MARK: - Steps

enum Step: Int, CaseIterable {
    case welcome, settings, install, done

    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .settings: return "Preferences"
        case .install: return "Installing"
        case .done: return "Complete"
        }
    }
}

// MARK: - Model

@MainActor
final class InstallerModel: ObservableObject {
    @Published var step: Step = .welcome
    @Published var settings = Settings()
    @Published var tasks: [TaskItem] = []
    @Published var currentIndex: Int = 0
    @Published var log: [LogLine] = []
    @Published var finished = false
    @Published var failed = false
    @Published var errorMessage = ""

    struct Settings {
        var model: String = "llama3.2:3b"
        var pullBothModels = true
        var autoRunTriangle = true          // permanently, as a login item
        var launchAfterInstall = true
        var createDesktopAlias = true
        var grantAccessibilityHint = true

        static let models = ["llama3.2:3b", "llama3.2:1b"]
    }

    struct TaskItem: Identifiable {
        let id = UUID()
        var title: String
        var detail: String
        var state: State = .pending

        enum State { case pending, running, done, failed, skipped }
    }

    struct LogLine: Identifiable {
        let id = UUID()
        let time = Date()
        let text: String
        let kind: Kind

        enum Kind { case info, ok, warn, error, cmd }
    }

    // MARK: - Build the plan

    func buildPlan() {
        var plan: [TaskItem] = [
            TaskItem(title: "Developer Tools", detail: "Verify Xcode Command Line Tools"),
            TaskItem(title: "Ollama Runtime", detail: "Download & install local LLM server"),
            TaskItem(title: "Model: \(settings.model)", detail: settings.pullBothModels ? "Also pulling llama3.2:1b fallback" : "Primary model only"),
            TaskItem(title: "Build NEXUS", detail: "swift build -c release"),
            TaskItem(title: "Red Triangle", detail: "Stage companion app + register auto-run"),
            TaskItem(title: "Verify", detail: "Ollama tool-calling + FixturePackage smoke test"),
            TaskItem(title: "Shell Integration", detail: "Terminal commands + aliases")
        ]
        if settings.createDesktopAlias {
            plan.append(TaskItem(title: "Shortcut", detail: "Add nexu command to /usr/local/bin"))
        }
        tasks = plan
    }

    var progress: Double {
        guard !tasks.isEmpty else { return 0 }
        let done = tasks.filter { $0.state == .done || $0.state == .skipped }.count
        return Double(done) / Double(tasks.count)
    }

    func log(_ text: String, kind: LogLine.Kind = .info) {
        log.append(LogLine(text: text, kind: kind))
        if log.count > 500 { log.removeFirst(log.count - 500) }
    }

    func mark(_ index: Int, _ state: TaskItem.State) {
        guard index >= 0, index < tasks.count else { return }
        tasks[index].state = state
    }
}

// MARK: - Command runner (nonisolated, temp dir, no shell injection)

enum Shell {
    @discardableResult
    static func run(_ launch: String, _ args: [String], cwd: URL? = nil) throws -> (code: Int32, out: String, err: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launch)
        p.arguments = args
        if let cwd { p.currentDirectoryURL = cwd }

        let o = Pipe(), e = Pipe()
        p.standardOutput = o
        p.standardError = e

        try p.run()
        p.waitUntilExit()

        let out = String(data: o.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let err = String(data: e.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (p.terminationStatus, out, err)
    }
}
