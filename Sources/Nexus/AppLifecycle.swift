// NEXUS App Lifecycle — boot phase, close phase, termination handshake.

import SwiftUI
import AppKit

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    enum Phase { case booting, running, closing }
    @Published var phase: Phase = .booting

    // MARK: - Interaction layer (3 entry intents + overlays)

    enum EntryMode: String {
        case mission = "MISSION"
        case steer = "STEER"
        case brainstorm = "BRAINSTORM"
        case direct = "DIRECT"
        case explain = "EXPLAIN"
        case pause = "PAUSE"
        case calendar = "CALENDAR"
    }

    /// Chip content for the current draft. Recomputed on every keystroke
    /// until the user cycles it manually (`modeLocked`).
    @Published var mode: EntryMode = .mission
    @Published var modeLocked = false

    @Published var explainOpen = false
    @Published var interrupt: InterruptPayload?
    @Published var dismissedInterruptIDs: Set<String> = []
    @Published var acknowledgment: String?
    @Published var pendingSwitch: PendingSwitch?
    @Published var pendingApproval: ApprovalPayload?

    func resetDraft() {
        mode = .mission
        modeLocked = false
    }
}

struct InterruptPayload: Identifiable {
    let id: String        // triggering event id
    let title: String
    let detail: String
}

struct PendingSwitch: Identifiable {
    let id = UUID()
    let sessionId: String
    let from: String
    let to: String
}

/// What happens to a running mission when you switch sessions.
enum SessionSwitchPref: String {
    case ask = "ask"
    case keepRunning = "continue"
    case pause = "pause"

    static let defaultsKey = "nexus.sessionSwitchPref"

    static var current: SessionSwitchPref {
        let raw = UserDefaults.standard.string(forKey: defaultsKey) ?? "ask"
        return SessionSwitchPref(rawValue: raw) ?? .ask
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: Self.defaultsKey)
    }

    var label: String {
        switch self {
        case .ask: return "Ask me"
        case .keepRunning: return "Continue running"
        case .pause: return "Pause mission"
        }
    }

    static func next() -> SessionSwitchPref {
        switch current {
        case .ask: return .keepRunning
        case .keepRunning: return .pause
        case .pause: return .ask
        }
    }
}

// MARK: - Approval

struct ApprovalPayload: Identifiable {
    let id: String
    let approvalId: String
    let toolName: String
    let risk: String
    let reason: String
    let arguments: [String: String]
}

struct ApprovalView: View {
    let approval: ApprovalPayload
    let onApprove: () -> Void
    let onDeny: () -> Void
    let onModify: (String) -> Void
    @State private var modifiedArgs: String = ""

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Palette.accent)
                        .font(.system(size: 16))
                    Text("APPROVAL REQUIRED")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Palette.accent)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(approval.toolName)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(Palette.white)
                    Text(approval.reason)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Palette.gray)
                    HStack {
                        Text("RISK:")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Palette.accent)
                        Text(approval.risk.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Palette.accent)
                    }
                }

                Divider()
                    .background(Palette.accent.opacity(0.3))

                VStack(alignment: .leading, spacing: 8) {
                    Text("ARGUMENTS")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Palette.gray)
                    ScrollView {
                        Text(approval.arguments.map { "\($0.key): \($0.value)" }.joined(separator: "\n"))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Palette.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(3)
                    }
                    .frame(maxHeight: 120)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("MODIFY ARGUMENTS (JSON)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Palette.gray)
                        TextEditor(text: $modifiedArgs)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Palette.white)
                            .frame(height: 80)
                            .padding(4)
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(3)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        onApprove()
                    } label: {
                        Text("APPROVE")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Palette.background)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Palette.accent)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return, modifiers: .command)

                    Button {
                        onModify(modifiedArgs)
                    } label: {
                        Text("MODIFY & APPROVE")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Palette.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        onDeny()
                    } label: {
                        Text("DENY")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Palette.gray)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(Color.red.opacity(0.5), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                }
            }
            .padding(24)
            .frame(width: 560, alignment: .leading)
            .background(Palette.background)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Palette.accent.opacity(0.55), lineWidth: 1)
            )
        }
        .onExitCommand(perform: onDeny)
    }
}

@MainActor
enum AppLifecycle {
    static var pendingTerminate = false
    static weak var closeProxy: CloseProxy?

    nonisolated(unsafe) static func log(_ message: String) {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss.SSS"
        let line = "[lifecycle \(fmt.string(from: Date()))] \(message)\n"
        FileHandle.standardError.write(line.data(using: .utf8)!)
    }

    static var visibleWindowCount: Int {
        NSApp.windows.filter { $0.isVisible }.count
    }

    /// Start the reversed boot sequence; completion closes/quits.
    static func beginClosing() {
        AppLifecycle.log("beginClosing phase=\(AppState.shared.phase) windows=\(visibleWindowCount)")
        guard AppState.shared.phase == .running else { return }
        AppState.shared.phase = .closing
    }

    static func finishClosing() {
        AppLifecycle.log("finishClosing phase=\(AppState.shared.phase) pendingTerminate=\(pendingTerminate) windows=\(visibleWindowCount)")
        if pendingTerminate {
            pendingTerminate = false
            NSApp.reply(toApplicationShouldTerminate: true)
        } else {
            closeProxy?.allowClose = true
            for window in NSApp.windows where window.isVisible {
                window.close()
            }
            closeProxy?.allowClose = false
            if NSApp.windows.filter({ $0.isVisible }).isEmpty {
                NSApp.terminate(nil)
            }
        }
    }
}

final class CloseProxy: NSObject, NSWindowDelegate {
    weak var original: NSWindowDelegate?
    var allowClose = false

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if allowClose {
            AppLifecycle.log("windowShouldClose allowClose=true")
            return true
        }
        AppLifecycle.log("windowShouldClose intercept phase=\(AppState.shared.phase)")
        if AppState.shared.phase == .running {
            AppLifecycle.beginClosing()
        }
        return false
    }

    override func responds(to sel: Selector!) -> Bool {
        if sel == #selector(NSWindowDelegate.windowShouldClose(_:)) { return true }
        return super.responds(to: sel) || (original?.responds(to: sel) ?? false)
    }

    override func forwardingTarget(for sel: Selector!) -> Any? {
        if original?.responds(to: sel) == true { return original }
        return super.forwardingTarget(for: sel)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLifecycle.log("didFinishLaunching windows=\(AppLifecycle.visibleWindowCount)")
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowWillClose(_:)), name: NSWindow.willCloseNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowDidChangeOcclusion(_:)), name: NSWindow.didChangeOcclusionStateNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidHide), name: NSApplication.didHideNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidUnhide), name: NSApplication.didUnhideNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidResignActive), name: NSApplication.didResignActiveNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(spaceDidChange), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            self.startWindowSnapshot()
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(willTerminate), name: NSApplication.willTerminateNotification, object: nil
        )
        DispatchQueue.main.async {
            for window in NSApp.windows where window.contentViewController != nil {
                if window.delegate is CloseProxy { continue }
                let proxy = CloseProxy()
                proxy.original = window.delegate
                window.delegate = proxy
                AppLifecycle.closeProxy = proxy
            }
        }
    }

    @MainActor @objc private func windowWillClose(_ note: Notification) {
        let windowDesc = (note.object as? NSWindow)?.description ?? "?"
        AppLifecycle.log("windowWillClose name=\(windowDesc) visibleLeft=\(AppLifecycle.visibleWindowCount)")
    }

    @MainActor @objc private func windowDidChangeOcclusion(_ note: Notification) {
        guard let w = note.object as? NSWindow else { return }
        let cls = w.className
        let vis = w.isVisible
        let occ = !w.occlusionState.contains(.visible)
        let alpha = w.alphaValue
        AppLifecycle.log("occlusionChange cls=\(cls) visible=\(vis) occluded=\(occ) alpha=\(alpha)")
    }

    @MainActor @objc private func appDidHide() { AppLifecycle.log("appDidHide") }
    @MainActor @objc private func appDidUnhide() { AppLifecycle.log("appDidUnhide") }
    @MainActor @objc private func appDidResignActive() { AppLifecycle.log("appDidResignActive") }
    @MainActor @objc private func spaceDidChange() { AppLifecycle.log("spaceDidChange") }

    @MainActor @objc private func willTerminate() {
        AppLifecycle.log("willTerminate phase=\(AppState.shared.phase)")
    }

    @MainActor private func startWindowSnapshot() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            Task { @MainActor [weak self] in
                let wins = NSApp.windows
                let desc = wins.map {
                    "\($0.className){vis=\($0.isVisible)mini=\($0.isMiniaturized)alpha=\($0.alphaValue)occ=\($0.occlusionState.contains(.visible))frame=\(Int($0.frame.minX)),\(Int($0.frame.minY))}"
                }.joined(separator: " | ")
                AppLifecycle.log("snapshot n=\(wins.count) active=\(NSApp.isActive) front=\((NSApp.keyWindow != nil)) :: \(desc)")
                self?.startWindowSnapshot()
            }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let visible = AppLifecycle.visibleWindowCount
        AppLifecycle.log("shouldTerminate phase=\(AppState.shared.phase) visible=\(visible)")
        switch AppState.shared.phase {
        case .booting:
            return .terminateNow
        case .closing:
            return .terminateNow
        case .running:
            if visible == 0 {
                AppLifecycle.log("shouldTerminate no visible window — terminating without animation")
                return .terminateNow
            }
            AppLifecycle.pendingTerminate = true
            AppState.shared.phase = .closing
            return .terminateLater
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}