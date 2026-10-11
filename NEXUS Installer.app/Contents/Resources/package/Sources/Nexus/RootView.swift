// NEXUS Root View — main window layout

import SwiftUI

struct RootView: View {
    @EnvironmentObject var engine: NexusEngine
    @ObservedObject private var appState = AppState.shared
    @State private var selectedTab = 0
    @State private var showTalk = false

    var body: some View {
        VStack(spacing: 0) {
            Taskbar(selectedTab: $selectedTab, showTalk: $showTalk)
            ContentView(selectedTab: selectedTab)
        }
        .background(Theme.windowBG)
        .scaleEffect(engine.worldTransition == nil ? 1.0 : 0.95)
        .animation(.easeInOut(duration: 0.3), value: engine.worldTransition)
        .overlay {
            if let transition = engine.worldTransition {
                WorldTransitionView(transition: transition)
            }
        }
        .overlay {
            EdgeLinesView()
        }
        .overlay {
            if let pending = appState.pendingApproval {
                ApprovalView(
                    approval: pending,
                    onApprove: { engine.sendApprovalResponse(approvalId: pending.approvalId, action: "approve") },
                    onDeny: { engine.sendApprovalResponse(approvalId: pending.approvalId, action: "deny") },
                    onModify: { args in engine.sendApprovalResponse(approvalId: pending.approvalId, action: "modify", args: args) }
                )
            }
        }
        .overlay {
            switch appState.phase {
            case .booting:
                BootAnimationView(reversed: false, duration: 1.8) {
                    appState.phase = .running
                }
            case .closing:
                BootAnimationView(reversed: true, duration: 1.5) {
                    AppLifecycle.finishClosing()
                }
            case .running:
                EmptyView()
            }
        }
        .keyboardShortcut(.return, modifiers: .command)
        .sheet(isPresented: $showTalk) {
            TalkView()
                .environmentObject(engine)
        }
        .onAppear {
            if CommandLine.arguments.contains("-talk") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                    showTalk = true
                }
            }
        }
    }
}

struct ContentView: View {
    let selectedTab: Int

    var body: some View {
        switch selectedTab {
        case 0: OverviewView()
        case 1: WorkflowsView()
        case 2: DashboardView()
        case 3: MemoryView()
        case 4: EventsView()
        case 5: PermissionsView()
        case 6: SettingsView()
        default: OverviewView()
        }
    }
}

// MARK: - Session switch: a running mission makes you choose (or follows pref)

struct SwitchAskView: View {
    let pending: PendingSwitch
    let onResolve: (SessionSwitchPref, Bool) -> Void
    let onCancel: () -> Void
    @State private var remember = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(alignment: .leading, spacing: 14) {
                Text("MISSION RUNNING")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Palette.accent)
                Text("Switch to \(pending.to)?")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(Palette.white)
                Text("The mission can continue in the background, or pause before switching.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Palette.gray)

                HStack(spacing: 10) {
                    Button { onResolve(.keepRunning, remember) } label: {
                        Text("CONTINUE")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Palette.background)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Palette.accent)
                    }
                    .buttonStyle(.plain)

                    Button { onResolve(.pause, remember) } label: {
                        Text("PAUSE")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Palette.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: onCancel) {
                        Text("CANCEL")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Palette.gray)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                }

                Toggle("Remember this choice", isOn: $remember)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Palette.grayDim)
            }
            .padding(26)
            .frame(width: 480, alignment: .leading)
            .background(Palette.background)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Palette.accent.opacity(0.55), lineWidth: 1)
            )
        }
        .onExitCommand(perform: onCancel)
    }
}