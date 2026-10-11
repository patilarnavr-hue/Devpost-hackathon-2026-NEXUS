// NEXUS Root View — main window layout

import SwiftUI

struct RootView: View {
    @EnvironmentObject var engine: NexusEngine
    @ObservedObject private var appState = AppState.shared
    @State private var selectedTab = 0
    @State private var showTalk = false
    @State private var showGuide = !UserDefaults.standard.bool(forKey: "nexus.guideDone")

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
                BootAnimationView(reversed: false, duration: 2.6) {
                    appState.phase = .running
                }
            case .closing:
                CloseAnimationView(duration: 1.8) {
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
        .overlay {
            if showGuide, appState.phase == .running {
                NEXUSGuide(onDone: { showGuide = false })
                    .environmentObject(engine)
                    .transition(.opacity)
            }
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
    @State private var lastTab = 0

    private var forward: Bool { selectedTab >= lastTab }

    var body: some View {
        ZStack {
            content(selectedTab)
                .id(selectedTab)
                .transition(.asymmetric(
                    insertion: .opacity
                        .combined(with: .scale(scale: 0.985))
                        .combined(with: .offset(x: forward ? 32 : -32)),
                    removal: .opacity
                        .combined(with: .scale(scale: 1.01))
                ))
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: selectedTab)
        .overlay(alignment: .top) {
            TabScanWipe(id: selectedTab)
        }
        .onAppear { lastTab = selectedTab }
        .onChange(of: selectedTab) { _, newVal in lastTab = newVal }
    }

    @ViewBuilder
    private func content(_ tab: Int) -> some View {
        switch tab {
        case 0: OverviewView().withPaneEntrance()
        case 1: WorkflowsView().withPaneEntrance()
        case 2: DashboardView().withPaneEntrance()
        case 3: MemoryView().withPaneEntrance()
        case 4: EventsView().withPaneEntrance()
        case 5: PermissionsView().withPaneEntrance()
        case 6: RoomsView().withPaneEntrance()
        case 7: SettingsView().withPaneEntrance()
        default: OverviewView().withPaneEntrance()
        }
    }
}

// MARK: - Pane entrance: content eases up + fades as one surface

private struct PaneEntrance: ViewModifier {
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 10)
            .onAppear {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) { shown = true }
            }
    }
}

extension View {
    func withPaneEntrance() -> some View { modifier(PaneEntrance()) }
}

// MARK: - Thin red scan that sweeps the pane on every tab switch

private struct TabScanWipe: View {
    let id: Int
    @State private var phase: CGFloat = -80

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(Palette.accent)
                .frame(width: 72, height: 1.5)
                .shadow(color: Palette.accent.opacity(0.9), radius: 7)
                .offset(x: phase, y: 0)
                .opacity(phase >= geo.size.width ? 0 : 1)
                .onAppear { sweep(width: geo.size.width) }
                .onChange(of: id) {
                    phase = -80
                    sweep(width: geo.size.width)
                }
        }
        .allowsHitTesting(false)
        .frame(height: 2)
    }

    private func sweep(width: CGFloat) {
        withAnimation(.linear(duration: 0.45)) {
            phase = width + 80
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            phase = -80
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