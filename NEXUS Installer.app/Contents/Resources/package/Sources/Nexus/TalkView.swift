// NEXUS Talk Dialog — send goals to the core, watch it work

import SwiftUI

struct TalkView: View {
    @EnvironmentObject var engine: NexusEngine
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @FocusState private var inputFocused: Bool

    let suggestions = [
        "Help me create an AI-powered study planner",
        "Research the best open-source LLMs for coding",
        "Summarize what NEXUS has done so far",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("TALK TO NEXUS")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
                Circle()
                    .fill(engine.isConnected ? Palette.seal : Palette.critical)
                    .frame(width: 8, height: 8)
                Text(engine.connectionStatus)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $message)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                    .frame(height: 110)
                    .focused($inputFocused)

                if message.isEmpty {
                    Text("Describe a goal for Nexus...\ne.g. Help me create an AI-powered study planner")
                        .font(.system(size: 13))
                        .foregroundColor(.gray.opacity(0.6))
                        .padding(14)
                        .allowsHitTesting(false)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("QUICK START")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.gray)
                ForEach(suggestions, id: \.self) { s in
                    Button(action: { message = s }) {
                        Text(s)
                            .font(.system(size: 12))
                            .foregroundColor(Palette.accent)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                liveStatus
                Spacer()
                Button(action: { dismiss() }) {
                    Text("Close")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button(action: sendGoal) {
                    HStack(spacing: 6) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 11))
                        Text("Send to Nexus")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(sendable ? Palette.accent : Color.gray.opacity(0.4))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(!sendable)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(20)
        .frame(width: 560, height: 360)
        .background(Color.black)
        .onAppear { inputFocused = true }
    }

    private var sendable: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && engine.isConnected
    }

    private var liveStatus: some View {
        HStack(spacing: 8) {
            Text(engine.state.rawValue)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Palette.accent)
            Text(engine.currentTask)
                .font(.system(size: 11))
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .frame(maxWidth: 240, alignment: .leading)
    }

    private func sendGoal() {
        guard sendable else { return }
        engine.sendGoal(message.trimmingCharacters(in: .whitespacesAndNewlines))
        message = ""
        dismiss()
    }
}
