// NEXUS Helper — your install assistant & project oracle.
// A separate companion (same Ollama brain) that knows everything about the
// NEXUS project: install steps, commands, architecture, troubleshooting.
// Auto-opens right after download/pull. Commands:
//   ask <anything> · doctor · reset · reinstall · fix · log · status · help
//
// Build:  swiftc -swift-version 5 -O NEXUSHelper/main.swift -o "NEXUS Helper"

import AppKit
import Foundation

// MARK: - Knowledge base (mirrors README + runbook; also reads live README when available)

let knowledge = """
# NEXUS — EvoHacks 2026 (AI for Automation)

## What it is
- NEXUS.app: mission-first macOS UI (SwiftUI). Boot/close animations, living edge lines,
  Overview/Workflows/Dashboard/Memory/Events/Permissions/Rooms/Settings tabs, first-run guide.
- NexusTriangle.app: menu-bar Red Triangle companion. Lens (⌥Space quick), chat (⌃⌥C),
  TEACH skills (record/stop/replay), autonomous agent (find/open_path/run_shell/wait tools),
  aliases (alias wd = watch downloads · wd runs it · aliaslen 3 · unalias wd),
  schedules (every day at 9am do coffee · schedules · unschedule x),
  folder watchers (watch downloads · watches · unwatch x),
  chore chains (chain a, b, c), file skills (rename/move/copy/trash/ls/cat/mkdir/touch/
  write <f> :: <text> / edit <f> :: <old> → <new> / open / run <cmd> / find / reveal / screenshot).
- Rooms: LAN collaboration over Bonjour (_nexuscollab._tcp) — create room, share code, chat +
  shared mission board. No accounts.
- Ollama (llama3.2:1b chat + llama3.2:3b agent) — the local brain. localhost:11434.

## Install
- One line:  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/patilarnavr-hue/Devpost-hackathon-2026-NEXUS/main/scripts/bootstrap.sh)"
- Or: double-click "NEXUS Installer.app" (self-contained).
- Or: git clone + bash install.sh
- First-time grants: Accessibility (System Settings → Privacy & Security), Local Network for Rooms.

## Files
- ~/Applications install targets: /Applications/NEXUS.app, /Applications/NexusTriangle.app,
  /Applications/NEXUS Helper.app
- State: ~/Library/Application Support/Nexus/ (schedules.json, watches.json, aliases.json,
  chores/, rooms/, bridge.jsonl)
- LaunchAgent: ~/Library/LaunchAgents/com.nexus.triangle.plist (launch at login)
- Demo target: ~/Documents/FixturePackage
- Signing identity: "NexusAgent Dev" (ad-hoc fallback), keychain ~/Library/Keychains/nexus-sign.keychain-db (pw: nexus)

## Troubleshooting
- Ollama offline: `ollama serve` then `ollama pull llama3.2:1b` and `ollama pull llama3.2:3b`
- Agent can't click: grant Accessibility, then run `killall NexusTriangle; open /Applications/NexusTriangle.app`
- Rooms empty: same Wi-Fi + allow Local Network; edit-port 8700-8799 free
- Rebuild: swift build -c release (app) / swiftc -swift-version 5 -O NexusTriangle/main.swift -o /tmp/tri
- Fresh clone: git clone … && cd Devpost-hackathon-2026-NEXUS && bash install.sh
- Full reset: ask me "reset" — I kill apps, remove installs, wipe state, unload launch agent.
"""

// MARK: - App model

final class HelperModel: ObservableObject {
    @Published var lines: [String] = []
    @Published var busy = false
    var onLine: ((String) -> Void)?

    func say(_ s: String) {
        DispatchQueue.main.async {
            self.lines.append(s)
            if self.lines.count > 400 { self.lines.removeFirst(self.lines.count - 400) }
            self.onLine?(s)
        }
    }

    struct Check { var ok: Bool; var name: String; var detail: String }
    private var checks: [Check] = []

    // MARK: doctor

    func doctor() {
        checks.removeAll()
        say("▸ RUNNING DOCTOR — 10 checks")

        check("Command Line Tools") { shell("/usr/bin/xcode-select", ["-p"]) }
        check("Swift toolchain") { shell("/usr/bin/swift", ["--version"]) }

        for app in ["NEXUS.app", "NexusTriangle.app", "NEXUS Helper.app"] {
            check("\(app) installed") { shell("/usr/bin/test", ["-d", "/Applications/\(app)"]) }
        }

        check("Ollama responding") { shell("/usr/bin/curl", ["-sfm", "3", "http://127.0.0.1:11434/api/version"]) }
        check("Model llama3.2:1b") { shell("/bin/zsh", ["-c", "curl -sf localhost:11434/api/tags | grep -q llama3.2:1b"]) }
        check("Model llama3.2:3b") { shell("/bin/zsh", ["-c", "curl -sf localhost:11434/api/tags | grep -q llama3.2:3b"]) }
        check("Accessibility granted") { AXIsProcessTrusted() ? (0, "", "") : (1, "", "grant in System Settings → Privacy & Security") }
        check("Launch agent loaded") { shell("/bin/zsh", ["-c", "launchctl list | grep -q com.nexus.triangle"]) }
        check("FixturePackage present") { shell("/usr/bin/test", ["-d", NSHomeDirectory() + "/Documents/FixturePackage"]) }

        let fails = checks.filter { !$0.ok }
        say(fails.isEmpty
            ? "✓ ALL CHECKS PASSED — NEXUS is healthy"
            : "✕ \(fails.count) issue(s):")
        for f in fails { say("   \(f.name) — \(f.detail)") }
    }

    private func check(_ name: String, _ block: () -> (Int32, String, String)) {
        let (code, out, err) = block()
        let ok = code == 0
        checks.append(Check(ok: ok, name: name, detail: err.isEmpty ? out.prefix(90).description : err.prefix(90).description))
        say("\(ok ? "✓" : "✕") \(name)")
    }

    // MARK: reset

    func reset() {
        say("▸ RESET — stopping everything")
        for p in ["Nexus", "NexusTriangle", "NEXUS Helper"] { shell("/usr/bin/pkill", ["-x", p]) }
        let agent = NSHomeDirectory() + "/Library/LaunchAgents/com.nexus.triangle.plist"
        shell("/bin/launchctl", ["bootout", "gui/\(getuid())/com.nexus.triangle"])
        try? FileManager.default.removeItem(atPath: agent)
        for app in ["/Applications/NEXUS.app", "/Applications/NexusTriangle.app", "/Applications/NEXUS Helper.app"] {
            let r = shell("/bin/rm", ["-rf", app])
            say("\(r.0 == 0 ? "✓" : "✕") removed \(app)")
        }
        let support = NSHomeDirectory() + "/Library/Application Support/Nexus"
        let r = shell("/bin/rm", ["-rf", support])
        say("\(r.0 == 0 ? "✓" : "✕") wiped \(support)")
        shell("/usr/bin/defaults", ["delete", "com.nexus.app"])
        shell("/usr/bin/defaults", ["delete", "com.nexus.helper"])
        say("✓ RESET COMPLETE — now reinstall:  ask me \"reinstall\" or run install.sh")
    }

    // MARK: reinstall

    func reinstall() {
        let src = sourceRepo()
        say("▸ REINSTALL — from \(src ?? "not found")")
        guard let src = src else {
            say("✕ repo not located — clone then reinstall:")
            say("   git clone https://github.com/patilarnavr-hue/Devpost-hackathon-2026-NEXUS.git && cd Devpost-hackathon-2026-NEXUS && bash install.sh")
            return
        }
        say("running install.sh — watch this window, it takes a few minutes…")
        busy = true
        DispatchQueue.global(qos: .userInitiated).async {
            let (code, out, _) = HelperModel.helperRun("/bin/bash", ["\(src)/install.sh"])
            DispatchQueue.main.async {
                self.busy = false
                let tail = out.split(separator: "\n").suffix(8).joined(separator: "\n")
                self.say(tail.isEmpty ? "(no output)" : tail)
                self.say(code == 0 ? "✓ REINSTALL DONE" : "✕ REINSTALL FAILED — ask me \"fix\"")
            }
        }
    }

    // MARK: fix (AI repairs)

    func fix() {
        let findings = healthSummary()
        say("▸ DIAGNOSING — \(findings.count) finding(s)")
        guard !findings.isEmpty else {
            say("✓ nothing looks broken — if something feels off, try \"reset\" then \"reinstall\"")
            return
        }
        let prompt = """
        The user's NEXUS install has these problems:
        \(findings.joined(separator: "\n"))

        \(knowledge)

        Reply with the exact terminal commands (one per line) to fix them, no prose.
        """
        ask(prompt) { reply in
            for line in reply.split(separator: "\n") {
                let t = line.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty { self.say("  \(t)") }
            }
        }
    }

    private func healthSummary() -> [String] {
        var out: [String] = []
        if shell("/usr/bin/xcode-select", ["-p"]).0 != 0 { out.append("Command Line Tools missing: xcode-select --install") }
        if !FileManager.default.fileExists(atPath: "/Applications/NEXUS.app") { out.append("NEXUS.app missing") }
        if !FileManager.default.fileExists(atPath: "/Applications/NexusTriangle.app") { out.append("NexusTriangle.app missing") }
        if shell("/usr/bin/curl", ["-sfm", "3", "http://127.0.0.1:11434/api/version"]).0 != 0 { out.append("Ollama not running: ollama serve") }
        let tags = shell("/usr/bin/curl", ["-sf", "http://127.0.0.1:11434/api/tags"]).1
        if !tags.contains("llama3.2:1b") { out.append("model llama3.2:1b missing: ollama pull llama3.2:1b") }
        if !tags.contains("llama3.2:3b") { out.append("model llama3.2:3b missing: ollama pull llama3.2:3b") }
        if !AXIsProcessTrusted() { out.append("Accessibility not granted for this app — enable in System Settings") }
        return out
    }

    // MARK: ask (Ollama)

    func ask(_ q: String, completion: @escaping (String) -> Void) {
        say("▸ THINKING — llama3.2:1b")
        let body: [String: Any] = [
            "model": "llama3.2:1b",
            "keep_alive": -1,
            "stream": false,
            "options": ["temperature": 0.2, "num_predict": 320],
            "messages": [
                ["role": "system", "content": """
                    You are the NEXUS Helper — a friendly macOS assistant inside a small dark panel.
                    You know everything about the NEXUS project (below). Answer concretely with
                    exact commands. Keep replies under 120 words. No markdown.

                    \(knowledge)
                    """] ,
                ["role": "user", "content": q]
            ]
        ]
        var req = URLRequest(url: URL(string: "http://127.0.0.1:11434/api/chat")!)
        req.httpMethod = "POST"
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 60
        URLSession.shared.dataTask(with: req) { data, _, err in
            let reply: String
            if let d = data,
               let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
               let m = j["message"] as? [String: Any],
               let c = m["content"] as? String {
                reply = c
            } else {
                reply = "Couldn't reach the local brain (Ollama). Run: ollama serve  ·  ollama pull llama3.2:1b"
            }
            DispatchQueue.main.async {
                self.busy = false
                completion(reply.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }.resume()
    }

    // MARK: status / log

    func status() {
        say("── STATUS ──")
        say("NEXUS.app          \(FileManager.default.fileExists(atPath: "/Applications/NEXUS.app") ? "installed" : "MISSING")")
        say("Triangle           \(FileManager.default.fileExists(atPath: "/Applications/NexusTriangle.app") ? "installed" : "MISSING")")
        let tags = shell("/usr/bin/curl", ["-sf", "http://127.0.0.1:11434/api/tags"]).1
        say("Ollama             \(tags.contains("llama3.2:1b") ? "online · llama3.2:1b" : "offline — run: ollama serve")")
        say("Accessibility      \(AXIsProcessTrusted() ? "granted" : "not granted")")
        say("Repo source        \(sourceRepo() ?? "unknown — set NEXUS_SRC")")
        say("State dir          \(NSHomeDirectory())/Library/Application Support/Nexus")
    }

    func showLog() {
        let url = NSHomeDirectory() + "/Library/Application Support/Nexus/bridge.jsonl"
        guard let txt = try? String(contentsOfFile: url, encoding: .utf8) else {
            say("no bridge log yet — the triangle writes one as it works"); return
        }
        for l in txt.split(separator: "\n").suffix(10) { say(String(l.prefix(140))) }
    }

    func showHelp() {
        let cmds = [
            "ask <question> — anything about install, fix, usage (offline)",
            "doctor — run all 10 health checks",
            "fix — diagnose + get exact repair commands",
            "reset — stop apps, remove installs, wipe state",
            "reinstall — rebuild from the repo (needs NEXUS_SRC or auto-detected)",
            "status — what's installed, ollama, permissions",
            "log — last events streamed from the triangle",
            "help — this list"
        ]
        for c in cmds { say("   \(c)") }
    }

    // MARK: helpers

    private func sourceRepo() -> String? {
        if let s = UserDefaults.standard.string(forKey: "nexus.src"), FileManager.default.fileExists(atPath: s) { return s }
        if let s = ProcessInfo.processInfo.environment["NEXUS_SRC"], FileManager.default.fileExists(atPath: s) { return s }
        for cand in [NSHomeDirectory() + "/.nexus-src", NSHomeDirectory() + "/Desktop/nexus v3", NSHomeDirectory() + "/Desktop/The real deal"] {
            if FileManager.default.fileExists(atPath: cand + "/install.sh") { return cand }
        }
        return nil
    }

    @discardableResult
    private func shell(_ bin: String, _ args: [String]) -> (Int32, String, String) {
        HelperModel.helperRun(bin, args)
    }

    static func helperRun(_ bin: String, _ args: [String]) -> (Int32, String, String) {
        let p = Process()
        let out = Pipe(), err = Pipe()
        p.standardOutput = out; p.standardError = err
        p.executableURL = URL(fileURLWithPath: bin)
        p.arguments = args
        do { try p.run() } catch { return (-1, "", error.localizedDescription) }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let d = err.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus,
                String(data: data, encoding: .utf8) ?? "",
                String(data: d, encoding: .utf8) ?? "")
    }
}

// MARK: - Panel (compact dark lens-style window)

final class Panel: NSPanel {
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 460, height: 340),
                   styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                   backing: .buffered, defer: false)
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        isFloatingPanel = true
        level = .floating
        backgroundColor = .black
        isOpaque = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
    }
}

final class StatusMenu {
    let item: NSStatusItem
    var openAction: () -> Void
    var doctorAction: () -> Void
    var quitAction: () -> Void

    init(open: @escaping () -> Void, doctor: @escaping () -> Void, quit: @escaping () -> Void) {
        openAction = open
        doctorAction = doctor
        quitAction = quit
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let b = item.button {
            b.image = NSImage(systemSymbolName: "questionmark.circle.fill", accessibilityDescription: "NEXUS Helper")
        }
        let menu = NSMenu()
        let openItem = NSMenuItem(title: "Open Helper", action: #selector(doOpen), keyEquivalent: "")
        let docItem = NSMenuItem(title: "Run Doctor", action: #selector(doDoctor), keyEquivalent: "")
        let quitItem = NSMenuItem(title: "Quit Helper", action: #selector(doQuit), keyEquivalent: "")
        menu.addItem(openItem)
        menu.addItem(docItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        for i in [openItem, docItem, quitItem] { i.target = self }
        item.menu = menu
    }

    @objc private func doOpen() { openAction() }
    @objc private func doDoctor() { doctorAction() }
    @objc private func doQuit() { quitAction() }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate, NSTextFieldDelegate {
    var panel: Panel!
    var model = HelperModel()
    var scroll: NSScrollView!
    var text: NSTextView!
    var field: NSTextField!
    var status: StatusMenu!

    func applicationDidFinishLaunching(_: Notification) {
        panel = Panel()
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 340))
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.black.cgColor
        panel.contentView = root

        // header
        let header = NSTextField(labelWithString: "▲ NEXUS HELPER")
        header.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)
        header.textColor = NSColor(calibratedRed: 1, green: 0.27, blue: 0.22, alpha: 1)
        header.frame = NSRect(x: 18, y: 300, width: 300, height: 22)
        root.addSubview(header)

        let online = NSTextField(labelWithString: "OFFLINE · LLAMA3.2:1B")
        online.font = NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
        online.textColor = NSColor(white: 0.55, alpha: 1)
        online.frame = NSRect(x: 330, y: 302, width: 115, height: 18)
        online.alignment = .right
        root.addSubview(online)

        // output
        scroll = NSScrollView(frame: NSRect(x: 12, y: 48, width: 436, height: 246))
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = true
        scroll.backgroundColor = NSColor(white: 0.045, alpha: 1)
        text = NSTextView(frame: scroll.bounds)
        text.isEditable = false
        text.backgroundColor = NSColor(white: 0.045, alpha: 1)
        text.textColor = NSColor(white: 0.9, alpha: 1)
        text.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        text.insertionPointColor = NSColor.white
        text.drawsBackground = false
        scroll.documentView = text
        root.addSubview(scroll)

        // input
        field = NSTextField(frame: NSRect(x: 12, y: 10, width: 436, height: 26))
        field.placeholderString = "ask anything · doctor · fix · reset · reinstall · status · log"
        field.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        field.textColor = .white
        field.backgroundColor = NSColor(white: 0.09, alpha: 1)
        field.isBordered = true
        field.focusRingType = .none
        field.target = self
        field.action = #selector(submit)
        root.addSubview(field)

        model.onLine = { [weak self] _ in
            guard let self = self else { return }
            let body = self.model.lines.suffix(120).joined(separator: "\n")
            if self.text.string != body {
                self.text.string = body
                self.text.scrollToEndOfDocument(nil)
            }
        }

        // greet — knowledge first
        model.say("▲ NEXUS HELPER — online, fully offline-brain")
        model.say("I know this whole project: install, fix, reset, what to do.")
        model.say("Try: doctor")
        model.say("")

        // warm the model in background
        warmModel()

        panel.makeKeyAndOrderFront(nil)
        status = StatusMenu(
            open: { [weak self] in
                guard let self = self else { return }
                self.panel.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            },
            doctor: { [weak self] in
                guard let self = self else { return }
                self.model.say("▸ DOCTOR (from menu bar)")
                self.model.doctor()
                self.panel.makeKeyAndOrderFront(nil)
            },
            quit: { NSApp.terminate(nil) }
        )
    }

    private func warmModel() {
        guard let url = URL(string: "http://127.0.0.1:11434/api/generate") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "model": "llama3.2:1b", "keep_alive": -1, "prompt": "hi", "stream": false,
            "options": ["num_predict": 1]
        ])
        req.timeoutInterval = 20
        URLSession.shared.dataTask(with: req).resume()
    }

    @objc private func submit() {
        let q = field.stringValue.trimmingCharacters(in: .whitespaces)
        field.stringValue = ""
        guard !q.isEmpty else { return }
        model.say("▸ \(q)")
        let low = q.lowercased()
        if low == "doctor" { model.doctor(); return }
        if low == "reset" { model.reset(); return }
        if low == "reinstall" { model.reinstall(); return }
        if low == "fix" || low == "repair" || low == "help me" { model.fix(); return }
        if low == "status" { model.status(); return }
        if low == "log" { model.showLog(); return }
        if low == "help" || low == "?" { model.showHelp(); return }
        model.busy = true
        model.ask(q) { reply in self.model.say("◂ \(reply)") }
    }
}

// MARK: - Entry

let app = NSApplication.shared
enum HelperDelegateHolder {
    nonisolated(unsafe) static var delegate: AppDelegate?
}
MainActor.assumeIsolated {
    let d = AppDelegate()
    HelperDelegateHolder.delegate = d
    app.delegate = d
    app.setActivationPolicy(.regular)
    app.run()
}
