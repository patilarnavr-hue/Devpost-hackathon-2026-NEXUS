// NEXUS SwiftUI App — connects to real Nexus core via WebSocket

import SwiftUI

@main
struct NEXUSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var engine = NexusEngine.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(engine)
                .frame(minWidth: 1100, minHeight: 680)
        }
        .defaultSize(width: 1180, height: 700)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Quit NEXUS") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            CommandGroup(after: .appInfo) {
                Button("About NEXUS") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            .applicationName: "NEXUS",
                            .applicationVersion: "1.0",
                            .credits: NSAttributedString(string: "EvoHacks 2026 — AI for Automation")
                        ]
                    )
                }
            }
        }
    }
}
