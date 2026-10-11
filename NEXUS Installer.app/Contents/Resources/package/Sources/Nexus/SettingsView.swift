// NEXUS Settings View — configuration and model info

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var engine: NexusEngine
    @State private var switchPref = SessionSwitchPref.current

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(20)

            VStack(spacing: 20) {
                SettingsSection(title: "Model") {
                    SettingsRow(label: "Provider", value: engine.modelProvider)
                    SettingsRow(label: "Model", value: engine.modelName)
                    SettingsRow(label: "Status", value: engine.isConnected ? "Available" : "Unavailable")
                }

                SettingsSection(title: "Connection") {
                    SettingsRow(label: "Server", value: "ws://127.0.0.1:8765")
                    SettingsRow(label: "Status", value: engine.connectionStatus)
                }

                SettingsSection(title: "Sessions") {
                    Button {
                        switchPref = SessionSwitchPref.next()
                        switchPref.save()
                    } label: {
                        SettingsRow(label: "Mission on switch", value: switchPref.label)
                    }
                    .buttonStyle(.plain)
                }

                SettingsSection(title: "Workspace") {
                    SettingsRow(label: "Path", value: FileManager.default.currentDirectoryPath)
                    SettingsRow(label: "Sandbox", value: "Enabled")
                }

                SettingsSection(title: "Security") {
                    SettingsRow(label: "Shell Access", value: "Disabled")
                    SettingsRow(label: "Auto-approve", value: "Disabled")
                    SettingsRow(label: "External Comm", value: "On-demand")
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(Color.black)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.gray)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                content
            }
            .background(Color.white.opacity(0.03))
            .cornerRadius(8)
        }
    }
}

struct SettingsRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.white)
            Spacer()
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
