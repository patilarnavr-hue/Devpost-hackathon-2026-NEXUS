import SwiftUI

struct Taskbar: View {
    @Binding var selectedTab: Int
    @Binding var showTalk: Bool
    @EnvironmentObject var engine: NexusEngine

    let tabs = [
        ("Overview", "gauge"),
        ("Workflows", "arrow.triangle.branch"),
        ("Dashboard", "square.grid.2x2"),
        ("Memory", "brain"),
        ("Events", "list.bullet.rectangle"),
        ("Permissions", "lock.shield"),
        ("Rooms", "person.3"),
        ("Settings", "gear"),
    ]

    private var activeName: String {
        engine.activeSession?.name ?? "SESSION"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("NEXUS")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.leading, 14)

                // Tabs — white text with a red underline when selected
                HStack(spacing: 2) {
                    ForEach(tabs.indices, id: \.self) { i in
                        Button(action: { selectedTab = i }) {
                            VStack(spacing: 3) {
                                Text(tabs[i].0)
                                    .font(.system(size: 11,
                                                  weight: selectedTab == i ? .semibold : .regular,
                                                  design: .monospaced))
                                    .lineLimit(1)
                                    .fixedSize()
                                    .foregroundColor(selectedTab == i ? .white : Palette.gray)
                                Rectangle()
                                    .fill(selectedTab == i ? Palette.accent : Color.clear)
                                    .frame(height: 2)
                            }
                            .padding(.top, 12)
                            .padding(.horizontal, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 8)

                // Connection status — compact, truncates instead of pushing
                HStack(spacing: 5) {
                    Circle()
                        .fill(engine.isConnected ? Palette.seal : Palette.critical)
                        .frame(width: 6, height: 6)
                    Text(engine.connectionStatus)
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 140, alignment: .leading)
                }

                // Sessions selector — hugs its content
                Menu {
                    Button("New Session") { engine.createSession() }
                    if !engine.sessions.isEmpty {
                        Divider()
                    }
                    ForEach(engine.sessions) { session in
                        Button(session.name) { engine.switchSession(session.id) }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(engine.activeSession != nil ? Palette.accent : Palette.grayDim)
                            .frame(width: 5, height: 5)
                        Text(activeName)
                            .font(.system(size: 10, design: .monospaced))
                            .lineLimit(1)
                            .fixedSize()
                            .foregroundColor(.white)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Palette.accent.opacity(0.15))
                    .cornerRadius(5)
                }
                .fixedSize()

                // Talk button
                Button(action: { showTalk = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 10))
                        Text("TALK")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Palette.accent)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .fixedSize()
                .padding(.trailing, 14)
            }
            .frame(height: 44)

            // Hairline
            Rectangle()
                .fill(Palette.accent.opacity(0.3))
                .frame(height: 1)
        }
        .background(Color.black)
    }
}
