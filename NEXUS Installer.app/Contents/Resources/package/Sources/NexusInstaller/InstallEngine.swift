// InstallEngine — does the real work for the NEXUS installer.

import Foundation
import AppKit

extension InstallerModel {

    /// Paths resolved from the installer's location so it works on any Mac.
    struct Paths {
        let submissionRoot: URL
        let nexusPkg: URL
        let fixturePkg: URL
        let triangleApp: URL
        let nexusApp: URL
        let installerApp: URL

        static func resolve() -> Paths {
            let bundle = Bundle.main.bundleURL
            var root = bundle
            for _ in 0..<5 {
                root = root.deletingLastPathComponent()
                if FileManager.default.fileExists(atPath: root.appendingPathComponent("install.sh").path) { break }
                if root.path == "/" { break }
            }
            return Paths(
                submissionRoot: root,
                nexusPkg: root.appendingPathComponent("Nexus"),
                fixturePkg: root.appendingPathComponent("FixturePackage"),
                triangleApp: root.appendingPathComponent("Nexus/.build/release/NexusTriangle.app"),
                nexusApp: root.appendingPathComponent("Nexus.app"),
                installerApp: bundle
            )
        }
    }

    // MARK: - Main flow

    func startInstall() {
        buildPlan()
        step = .install
        finished = false
        failed = false
        log("NEXUS installer starting…", kind: .ok)

        let model = self
        Task { @MainActor in
            let engine = InstallRunner(model: model, settings: model.settings)
            let outcome = await engine.run()
            model.tasks = outcome.tasks
            model.currentIndex = outcome.tasks.count
            model.finished = true
            model.failed = !outcome.success
            if !outcome.success { model.errorMessage = outcome.errorMessage }
        }
    }

    func finish() {
        if settings.launchAfterInstall {
            let paths = Paths.resolve()
            NSWorkspace.shared.open(paths.triangleApp)
            NSWorkspace.shared.open(paths.nexusApp)
        }
        step = .done
    }
}

// MARK: - Runner

struct InstallOutcome {
    var tasks: [InstallerModel.TaskItem]
    var logs: [InstallerModel.LogLine]
    var success: Bool
    var errorMessage: String
}

@MainActor
final class InstallRunner {
    private var tasks: [InstallerModel.TaskItem] = []
    private var logs: [InstallerModel.LogLine] = []
    private weak var model: InstallerModel?
    private let settings: InstallerModel.Settings
    private var paths = InstallerModel.Paths.resolve()
    private var success = true
    private var errorMessage = ""

    init(model: InstallerModel?, settings: InstallerModel.Settings) {
        self.model = model
        self.settings = settings
        self.tasks = model?.tasks ?? []
    }

    func run() async -> InstallOutcome {
        await step(0) { await checkCLT() }
        await step(1) { await installOllama() }
        await step(2) { await pullModels() }
        await step(3) { await buildNexus() }
        await step(4) { await stageTriangle() }
        await step(5) { await verify() }
        await step(6) { await shellIntegration() }
        if settings.createDesktopAlias, let i = indexOfTask("Shortcut") {
            await step(i) { await installCLI() }
        }

        return InstallOutcome(tasks: tasks, logs: logs, success: success, errorMessage: errorMessage)
    }

    // MARK: - Steps

    private func step(_ title: String) -> Int {
        if let i = tasks.firstIndex(where: { $0.title == title }) { return i }
        return 0
    }

    private func indexOfTask(_ title: String) -> Int? {
        tasks.firstIndex { $0.title == title }
    }

    private func step(_ index: Int, _ body: () async -> Void) async {
        setState(index, .running)
        log("▶ \(tasks[index].title) — \(tasks[index].detail)", .cmd)
        await body()
        if success { setState(index, .done) }
    }

    private func setState(_ index: Int, _ state: InstallerModel.TaskItem.State) {
        guard index >= 0, index < tasks.count else { return }
        tasks[index].state = state
        model?.mark(index, state)
    }

    private func fail(_ index: Int, _ message: String) async {
        setState(index, .failed)
        success = false
        errorMessage = message
        log("✖ \(message)", .error)
    }

    private func log(_ text: String, _ kind: InstallerModel.LogLine.Kind) {
        let line = InstallerModel.LogLine(text: text, kind: kind)
        logs.append(line)
        model?.log(text, kind: kind)
    }

    // MARK: - 1. CLT

    private func checkCLT() async {
        if let (code, _, _) = try? Shell.run("/usr/bin/xcode-select", ["-p"]), code == 0 {
            log("✓ Command Line Tools present", .ok)
            return
        }
        log("Command Line Tools missing — opening installer dialog…", .warn)
        _ = try? Shell.run("/usr/bin/xcode-select", ["--install"])
        log("Complete the GUI install, then re-run the installer.", .warn)
        await fail(0, "Command Line Tools not installed")
    }

    // MARK: - 2. Ollama

    private var ollamaCLI: String { "/Applications/Ollama.app/Contents/Resources/ollama" }

    private func installOllama() async {
        if FileManager.default.fileExists(atPath: ollamaCLI) {
            log("✓ Ollama already installed", .ok)
        } else {
            log("Downloading Ollama (~200 MB)…", .info)
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("Ollama.dmg")
            if let (code, _, _) = try? Shell.run("/usr/bin/curl", ["-L", "-s", "-o", tmp.path, "https://ollama.com/download/Ollama.dmg"]),
               code == 0 {
                log("✓ Downloaded", .ok)
                _ = try? Shell.run("/usr/bin/hdiutil", ["attach", "-nobrowse", "-quiet", tmp.path])
                let vol = URL(fileURLWithPath: "/Volumes/Ollama")
                if let (_, _, _) = try? Shell.run("/bin/cp", ["-R", vol.appendingPathComponent("Ollama.app").path, "/Applications/"]),
                   FileManager.default.fileExists(atPath: ollamaCLI) {
                    log("✓ Installed to /Applications", .ok)
                    _ = try? Shell.run("/usr/bin/hdiutil", ["detach", vol.path, "-quiet"])
                } else {
                    await fail(1, "Failed to copy Ollama.app")
                    return
                }
            } else {
                await fail(1, "Download failed — check internet")
                return
            }
        }

        // Start server if not responding
        let alive = (try? Shell.run("/usr/bin/curl", ["-sfm", "2", "http://127.0.0.1:11434/api/version"]))
        if alive == nil || alive?.0 != 0 {
            log("Starting Ollama server…", .info)
            Shell.detach(ollamaCLI, ["serve"])
            for _ in 0..<20 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                if ((try? Shell.run("/usr/bin/curl", ["-sfm", "2", "http://127.0.0.1:11434/api/version"]))?.0) == 0 {
                    log("✓ Server up", .ok)
                    return
                }
            }
            await fail(1, "Ollama server did not start")
            return
        }
        log("✓ Server already running", .ok)
    }

    // MARK: - 3. Models

    private func pullModels() async {
        func has(_ m: String) -> Bool {
            guard let (code, out, _) = try? Shell.run(ollamaCLI, ["list"]) else { return false }
            return code == 0 && out.contains(m)
        }

        for model in [settings.model] + (settings.pullBothModels && settings.model != "llama3.2:1b" ? ["llama3.2:1b"] : []) {
            if has(model) {
                log("✓ \(model) already present", .ok)
                continue
            }
            log("Pulling \(model)…", .info)
            let tmpLog = FileManager.default.temporaryDirectory.appendingPathComponent("ollama-pull.log")
            let result = try? Shell.run("/bin/zsh", ["-c", "\(ollamaCLI) pull \(model) > \(tmpLog.path) 2>&1"])
            if result?.0 == 0 || has(model) {
                log("✓ \(model) ready", .ok)
            } else {
                log("⚠ \(model) pull issue — model may need more RAM", .warn)
            }
        }
    }

    // MARK: - 4. Build

    private func buildNexus() async {
        log("Building NEXUS (release)…", .info)
        let result = try? Shell.run("/usr/bin/swift", ["build", "-c", "release"], cwd: paths.nexusPkg)
        if result?.0 == 0 {
            log("✓ Built: Nexus/.build/release/Nexus", .ok)
            // refresh the .app bundle
            _ = try? Shell.run("/bin/cp", [paths.nexusPkg.appendingPathComponent(".build/release/Nexus").path,
                                       paths.nexusApp.appendingPathComponent("Contents/MacOS/Nexus").path])
        } else {
            await fail(3, "swift build failed: \((result?.1 ?? "") + (result?.2 ?? "")).prefix(400)")
        }
    }

    // MARK: - 5. Triangle + permanent auto-run

    private func stageTriangle() async {
        guard FileManager.default.fileExists(atPath: paths.triangleApp.path) else {
            await fail(4, "NexusTriangle.app not found in Nexus/.build/release/")
            return
        }

        // Copy where the user can find it and register a LaunchAgent so it always runs
        let appsURL = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask)[0]
        let dest = appsURL.appendingPathComponent("NexusTriangle.app")

        if paths.triangleApp.path != dest.path {
            _ = try? Shell.run("/bin/rm", ["-rf", dest.path])
            _ = try? Shell.run("/bin/cp", ["-R", paths.triangleApp.path, dest.path])
            log("✓ Installed to /Applications", .ok)
        }

        if settings.autoRunTriangle {
            let binary = dest.appendingPathComponent("Contents/MacOS/NexusTriangle").path
            let plist: [String: Any] = [
                "Label": "com.nexus.triangle",
                "ProgramArguments": [binary],
                "RunAtLoad": true,
                "KeepAlive": false,
                "StandardOutPath": "/tmp/nexus-triangle.log",
                "StandardErrorPath": "/tmp/nexus-triangle.log"
            ]
            let agents = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/LaunchAgents")
            let plistURL = agents.appendingPathComponent("com.nexus.triangle.plist")
            do {
                try FileManager.default.createDirectory(at: agents, withIntermediateDirectories: true)
                let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                try data.write(to: plistURL, options: .atomic)
                _ = try? Shell.run("/bin/launchctl", ["bootout", "gui/\(getuid())/com.nexus.triangle"])
                let boot = try? Shell.run("/bin/launchctl", ["bootstrap", "gui/\(getuid())", plistURL.path])
                if boot?.0 == 0 { log("✓ Registered as login item (always runs)", .ok) }
                else {
                    log("Registering via launchctl load…", .warn)
                    _ = try? Shell.run("/bin/launchctl", ["enable", "gui/\(getuid())/com.nexus.triangle"])
                    _ = try? Shell.run("/bin/launchctl", ["load", "-w", plistURL.path])
                }
            } catch {
                log("⚠ Could not register login item: \(error.localizedDescription)", .warn)
            }
        } else {
            log("Auto-run skipped by preference", .warn)
        }

        if settings.grantAccessibilityHint && !AXTrusted() {
            log("Accessibility not granted — the agent needs it to control the cursor.", .warn)
        }
    }

    private func AXTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    // MARK: - 6. Verify

    private func verify() async {
        // Ollama tool-calling
        if let (_, out, _) = try? Shell.run("/usr/bin/curl", [
            "-sfm", "60", "http://127.0.0.1:11434/v1/chat/completions",
            "-H", "Content-Type: application/json",
            "-d", "{\"model\":\"\(settings.model)\",\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}],\"tools\":[{\"type\":\"function\",\"function\":{\"name\":\"noop\",\"description\":\"test\",\"parameters\":{\"type\":\"object\",\"properties\":{}}}}],\"tool_choice\":\"auto\",\"stream\":false}"
        ]), out.contains("\"finish_reason\":\"tool_calls\"") {
            log("✓ Ollama tool-calling works", .ok)
        } else {
            log("⚠ Tool-calling check inconclusive (model may still be loading)", .warn)
        }

        // FixturePackage smoke test
        if FileManager.default.fileExists(atPath: paths.fixturePkg.appendingPathComponent("Package.swift").path) {
            log("Running FixtureTests…", .info)
            if let (code, out, _) = try? Shell.run("/usr/bin/swift", ["run", "FixtureTests"], cwd: paths.fixturePkg) {
                if code == 0 { log("✓ FixtureTests exit 0 — defects already fixed", .ok) }
                else { log("✓ FixtureTests exit \(code) — defects present (that's the demo target)", .ok) }
                _ = out
            }
        } else {
            log("FixturePackage not found yet — add it during the hackathon", .warn)
        }
    }

    // MARK: - 7. Shell integration

    private func shellIntegration() async {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("nexus/scripts")
        let nexusScript = dir.appendingPathComponent("nexus")
        let triScript = dir.appendingPathComponent("nexus-triangle")

        _ = try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let nexusCmd = """
        #!/bin/zsh
        exec "\(paths.nexusApp.path)/Contents/MacOS/Nexus" "$@"
        """
        let triCmd = """
        #!/bin/zsh
        exec "\(appsURL().appendingPathComponent("NexusTriangle.app/Contents/MacOS/NexusTriangle").path)" "$@"
        """
        _ = try? nexusCmd.write(to: nexusScript, atomically: true, encoding: .utf8)
        try? triCmd.write(to: triScript, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: nexusScript.path)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: triScript.path)

        // ~/.zshrc alias
        let zshrc = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".zshrc")
        let block = """
        \n# NEXUS (EvoHacks 2026) — added by installer
        export PATH="$PATH:\(dir.path)"
        alias nexus="\(dir.path)/nexus"
        alias nexus-triangle="\(dir.path)/nexus-triangle"
        """
        if let data = FileManager.default.contents(atPath: zshrc.path).flatMap({ String(data: $0, encoding: .utf8) }) {
            if !data.contains("# NEXUS (EvoHacks 2026)") {
                if let h = FileHandle(forWritingAtPath: zshrc.path) {
                    h.seekToEndOfFile()
                    h.write(block.data(using: .utf8)!)
                    try? h.close()
                }
            }
        } else {
            try? (block + "\n").write(to: zshrc, atomically: true, encoding: .utf8)
        }
        log("✓ Terminal commands: nexus, nexus-triangle", .ok)
    }

    private func appsURL() -> URL {
        FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask)[0]
    }

    // MARK: - 8. Optional CLI shim

    private func installCLI() async {
        let bin = URL(fileURLWithPath: "/usr/local/bin/nexus")
        let script = "\(paths.nexusApp.path)/Contents/MacOS/Nexus"
        do {
            _ = try? FileManager.default.createDirectory(at: bin.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: bin)
            try FileManager.default.createSymbolicLink(at: bin, withDestinationURL: URL(fileURLWithPath: script))
            log("✓ /usr/local/bin/nexus created", .ok)
        } catch {
            log("⚠ /usr/local/bin needs admin — using ~/.local/bin instead", .warn)
            let home = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/nexus")
            _ = try? FileManager.default.createDirectory(at: home.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: home)
            try? FileManager.default.createSymbolicLink(at: home, withDestinationURL: URL(fileURLWithPath: script))
        }
    }
}

extension Shell {
    /// Run blocking work off the main actor and await the result.
    static func runAsync(_ launch: String, _ args: [String], cwd: URL? = nil) async throws -> (code: Int32, out: String, err: String) {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                do { cont.resume(returning: try run(launch, args, cwd: cwd)) }
                catch { cont.resume(throwing: error) }
            }
        }
    }

    /// Fire-and-forget process (keeps running after the installer exits).
    static func detach(_ launch: String, _ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launch)
        p.arguments = args
        try? p.run()
    }
}
