// NEXUS Rooms — LAN group chat + shared task board.
// Create a room, share the code (or nexus:// link), collaborate live.

import SwiftUI

struct RoomsView: View {
    @ObservedObject private var collab = CollabService.shared
    @State private var joinCode = ""
    @State private var draft = ""
    @State private var taskDraft = ""
    @FocusState private var chatFocused: Bool
    @FocusState private var taskFocused: Bool

    var body: some View {
        Group {
            if collab.roomCode == nil {
                lobby
            } else {
                room
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
        .onOpenURL { url in
            if url.scheme == "nexus", url.host == "room",
               let code = url.pathComponents.last {
                collab.join(code)
            }
        }
    }

    // MARK: - Lobby

    private var lobby: some View {
        VStack(spacing: 22) {
            Spacer()
            Text("COLLAB ROOMS")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Text("Chat + collaborate with anyone on your network.\nNo server, no accounts — rooms live on the local link.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Palette.gray)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button {
                    collab.createRoom()
                } label: {
                    Text("CREATE ROOM")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(Palette.accent)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                HStack(spacing: 0) {
                    TextField("CODE", text: $joinCode)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .frame(width: 70)
                        .focused($joinFocused)
                        .onSubmit { collab.join(joinCode) }
                    Button { collab.join(joinCode) } label: {
                        Text("JOIN")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .cornerRadius(6)
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                }
                .background(Palette.white.opacity(0.06))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.accent.opacity(0.4), lineWidth: 1))
            }

            if !collab.lastError.isEmpty {
                Text(collab.lastError)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Palette.accent)
            }

            Text("You: \(collab.handle)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Palette.grayDim)
                .padding(.top, 8)
            Spacer()
        }
    }

    @FocusState private var joinFocused: Bool

    // MARK: - Room

    private var room: some View {
        VStack(spacing: 0) {
            // Header: room code + members + leave
            HStack(spacing: 14) {
                Text("ROOM")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Palette.gray)
                Text(collab.roomCode ?? "")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(Palette.accent)
                    .tracking(4)
                Button { collab.copyInvite() } label: {
                    Label("COPY LINK", systemImage: "link")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Palette.white.opacity(0.08))
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 8) {
                    ForEach(collab.members) { m in
                        HStack(spacing: 4) {
                            Circle().fill(m.id == collab.myID ? Palette.accent : Palette.seal)
                                .frame(width: 6, height: 6)
                            Text(m.handle)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Palette.white.opacity(0.05))
                        .cornerRadius(4)
                    }
                }

                Button { collab.leave() } label: {
                    Text("LEAVE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Palette.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Palette.accent.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.black)
            Rectangle().fill(Palette.accent.opacity(0.3)).frame(height: 1)

            HStack(spacing: 0) {
                // Chat
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(collab.messages) { m in
                                    chatRow(m)
                                        .id(m.id)
                                        .transition(.opacity.combined(with: .offset(y: 8)))
                                }
                            }
                            .padding(14)
                            .animation(.spring(response: 0.32, dampingFraction: 0.85), value: collab.messages.count)
                        }
                        .onChange(of: collab.messages.count) {
                            if let last = collab.messages.last {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                    }

                    Rectangle().fill(Palette.white.opacity(0.08)).frame(height: 1)
                    HStack(spacing: 8) {
                        TextField("message the room…", text: $draft)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white)
                            .focused($chatFocused)
                            .onSubmit(sendDraft)
                        Button(action: sendDraft) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Palette.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }

                // Task board
                VStack(spacing: 0) {
                    HStack {
                        Text("MISSION BOARD")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Palette.gray)
                        Spacer()
                        Text("\(collab.tasks.filter(\.done).count)/\(collab.tasks.count)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Palette.accent)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    Rectangle().fill(Palette.white.opacity(0.08)).frame(height: 1)

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(collab.tasks) { t in
                                HStack(spacing: 8) {
                                    Button { collab.toggleTask(t.id) } label: {
                                        Image(systemName: t.done ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 13))
                                            .foregroundColor(t.done ? Palette.accent : Palette.gray)
                                            .scaleEffect(t.done ? 1.15 : 1.0)
                                            .animation(.spring(response: 0.28, dampingFraction: 0.6), value: t.done)
                                    }
                                    .buttonStyle(.plain)
                                    Text(t.text)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(t.done ? Palette.grayDim : .white)
                                        .strikethrough(t.done, color: Palette.grayDim)
                                    Spacer()
                                    Text(t.by)
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(Palette.grayDim)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 4)
                                .transition(.opacity.combined(with: .offset(y: 6)))
                            }
                        }
                        .padding(.vertical, 10)
                        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: collab.tasks.count)
                    }

                    Rectangle().fill(Palette.white.opacity(0.08)).frame(height: 1)
                    HStack(spacing: 8) {
                        TextField("add a mission…", text: $taskDraft)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white)
                            .focused($taskFocused)
                            .onSubmit {
                                collab.addTask(taskDraft)
                                taskDraft = ""
                            }
                        Button {
                            collab.addTask(taskDraft)
                            taskDraft = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Palette.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .frame(minWidth: 240, maxWidth: 300)
            }
        }
    }

    private func chatRow(_ m: CollabMessage) -> some View {
        let mine = m.from == collab.handle
        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: mine ? .trailing : .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(m.from)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(mine ? Palette.accent : Palette.gray)
                    Text(m.ts, style: .time)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(Palette.grayDim)
                }
                Text(m.text)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 40)
        }
        .padding(.horizontal, 6)
    }

    private func sendDraft() {
        collab.send(draft)
        draft = ""
    }
}
