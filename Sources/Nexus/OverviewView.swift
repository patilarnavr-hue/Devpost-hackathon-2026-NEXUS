// NEXUS Overview — machine transcript. Persistent chats + memory, isolated per copy.

import SwiftUI

struct OverviewView: View {
    @ObservedObject private var chat = ChatStore.shared
    @ObservedObject private var memory = MemoryStore.shared
    @ObservedObject private var identity = NexusIdentity.shared
    @ObservedObject private var ollama = OllamaService.shared
    @State private var input = ""
    @State private var sidebarTab = 0
    @State private var memoryInput = ""
    @State private var memoryTags = ""
    @State private var showCopyInfo = false
    @State private var renameText = ""
    @FocusState private var inputFocused: Bool

    private let thinkingID = "thinking"
    @State private var pinnedToBottom = true

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Theme.hairline).frame(width: 1)
            chatColumn
        }
        .background(Theme.windowBG)
        .onAppear { inputFocused = true }
        .sheet(isPresented: $showCopyInfo) { copyInfoSheet }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            Button(action: { renameText = identity.info.name; showCopyInfo = true }) {
                HStack(spacing: 9) {
                    NexusMark(size: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("NEXUS")
                            .font(Theme.title(.bold))
                            .tracking(3)
                            .foregroundColor(Theme.textPrimary)
                        HStack(spacing: 5) {
                            Circle().fill(Theme.green).frame(width: 4, height: 4)
                            Text(identity.info.name)
                                .font(Theme.caption())
                                .foregroundColor(Theme.textTertiary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Theme.textTertiary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Text("COPY \(identity.shortID) · \(chat.sessions.count) CHATS · \(memory.count) MEM")
                .font(Theme.caption(.medium))
                .tracking(0.5)
                .foregroundColor(Theme.textTertiary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)

            tabBar
                .frame(height: 34)
                .padding(.horizontal, 12)

            Rectangle().fill(Theme.hairline).frame(height: 1)

            if sidebarTab == 0 { chatList } else { memoryPanel }
        }
        .frame(width: Theme.sidebarWidth)
        .background(Theme.sidebarBG)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tab("CHATS", badge: chat.sessions.count, index: 0)
            Rectangle().fill(Theme.hairline).frame(width: 1)
            tab("MEMORY", badge: memory.count, index: 1)
        }
    }

    private func tab(_ title: String, badge: Int, index: Int) -> some View {
        Button(action: { withAnimation(.easeOut(duration: 0.12)) { sidebarTab = index } }) {
            VStack(spacing: 4) {
                HStack(spacing: 5) {
                    Text(title)
                        .font(Theme.caption(.bold))
                        .tracking(1)
                    Text("\(badge)")
                        .font(Theme.caption())
                        .foregroundColor(Theme.textTertiary)
                }
                .foregroundColor(sidebarTab == index ? Theme.accent : Theme.textSecondary)
                Rectangle()
                    .fill(sidebarTab == index ? Theme.accent : .clear)
                    .frame(height: 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 9)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chat list

    private var chatList: some View {
        VStack(spacing: 0) {
            Button(action: { chat.newChat() }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 10, weight: .black))
                    Text("NEW")
                        .font(Theme.caption(.bold))
                        .tracking(1)
                }
                .foregroundColor(Theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Theme.accentWash)
                .overlay(Rectangle().stroke(Theme.accent.opacity(0.6), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 1) {
                    ForEach(chat.sessions) { session in chatRow(session) }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 10)
            }
        }
    }

    private func chatRow(_ session: ChatStore.ChatSession) -> some View {
        let active = session.id == chat.activeID
        return Button(action: { chat.selectChat(session.id) }) {
            HStack(spacing: 7) {
                Rectangle()
                    .fill(active ? Theme.accent : .clear)
                    .frame(width: 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(session.title)
                        .font(Theme.label(active ? .bold : .regular))
                        .foregroundColor(active ? Theme.textPrimary : Theme.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text("\(session.messages.count) MSG · \(session.updatedAt, style: .relative)")
                        .font(Theme.caption())
                        .foregroundColor(Theme.textTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)

                Button(action: { chat.deleteChat(session.id) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.textTertiary)
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Delete chat")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(active ? Theme.raisedBG : .clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Memory panel

    private var memoryPanel: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    TextField("remember something…", text: $memoryInput)
                        .textFieldStyle(.plain)
                        .font(Theme.label())
                        .foregroundColor(Theme.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .background(Theme.panelBG)
                        .overlay(Rectangle().stroke(Theme.hairlineStrong, lineWidth: 1))
                    Button(action: addMemory) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(Theme.accent)
                            .frame(width: 26, height: 26)
                            .overlay(Rectangle().stroke(Theme.accent.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(memoryInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(memoryInput.trimmingCharacters(in: .whitespaces).isEmpty ? 0.35 : 1)
                    .keyboardShortcut(.return, modifiers: .command)
                }

                HStack(spacing: 6) {
                    Text("TAGS")
                        .font(Theme.caption(.bold))
                        .foregroundColor(Theme.textTertiary)
                    TextField("space separated", text: $memoryTags)
                        .textFieldStyle(.plain)
                        .font(Theme.caption())
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Theme.panelBG)
                .overlay(Rectangle().stroke(Theme.hairline, lineWidth: 1))

                HStack(spacing: 6) {
                    Text("FIND")
                        .font(Theme.caption(.bold))
                        .foregroundColor(Theme.textTertiary)
                    TextField("search memory", text: $memory.query)
                        .textFieldStyle(.plain)
                        .font(Theme.caption())
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Theme.panelBG)
                .overlay(Rectangle().stroke(Theme.hairline, lineWidth: 1))
            }
            .padding(10)

            Rectangle().fill(Theme.hairline).frame(height: 1)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(memory.filtered) { entry in memoryRow(entry) }
                    if memory.filtered.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: memory.count == 0 ? "brain" : "magnifyingglass")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.textTertiary)
                            Text(memory.count == 0 ? "NO MEMORIES" : "NO MATCHES")
                                .font(Theme.caption(.bold))
                                .tracking(1)
                                .foregroundColor(Theme.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                    }
                }
            }

            Rectangle().fill(Theme.hairline).frame(height: 1)

            HStack {
                Text(memory.statLine.uppercased())
                    .font(Theme.caption())
                    .foregroundColor(Theme.textTertiary)
                Spacer()
                Button("CLEAR") { memory.clearAll() }
                    .font(Theme.caption(.bold))
                    .foregroundColor(Theme.accent)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func memoryRow(_ entry: MemoryStore.Entry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 6) {
                if entry.pinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 7))
                        .foregroundColor(Theme.accent)
                }
                Text(entry.content)
                    .font(Theme.label())
                    .foregroundColor(Theme.textPrimary.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                Text(entry.source.uppercased())
                    .font(Theme.caption())
                    .foregroundColor(Theme.textTertiary)
                if !entry.tags.isEmpty {
                    Text(entry.tags.prefix(3).map { "#\($0)" }.joined(separator: " "))
                        .font(Theme.caption())
                        .foregroundColor(Theme.accentSoft)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)

                Button(action: { memory.togglePin(entry.id) }) {
                    Image(systemName: entry.pinned ? "pin.fill" : "pin")
                        .font(.system(size: 8))
                        .foregroundColor(Theme.textTertiary)
                }
                .buttonStyle(.plain)
                Button(action: { memory.delete(entry.id) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(entry.pinned ? Theme.accentWash : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
    }

    private func addMemory() {
        let (clean, inlineTags) = MemoryStore.parseTags(from: memoryInput)
        let extra = memoryTags
            .split(separator: " ").map { String($0).lowercased().replacingOccurrences(of: "#", with: "") }
            .filter { !$0.isEmpty }
        memory.add(clean, tags: extra.isEmpty ? inlineTags : extra, source: "manual")
        memoryInput = ""
        memoryTags = ""
    }

    // MARK: - Chat column

    private var chatColumn: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Theme.hairline).frame(height: 1)
            messages
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Rectangle().fill(Theme.hairline).frame(height: 1)
            modeBar
            Rectangle().fill(Theme.hairline).frame(height: 1)
            composer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text((chat.activeSession?.title ?? "NEW CHAT").uppercased())
                .font(Theme.title(.bold))
                .tracking(1.5)
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Circle()
                    .fill(ollama.isAvailable ? Theme.green : Theme.accent)
                    .frame(width: 5, height: 5)
                Text(ollama.isAvailable ? "OLLAMA ONLINE" : "OLLAMA OFFLINE")
                    .font(Theme.caption(.bold))
                    .tracking(0.8)
                    .foregroundColor(ollama.isAvailable ? Theme.green : Theme.accent)
            }

            if ollama.isAvailable {
                Text(ollama.selectedModel)
                    .font(Theme.caption())
                    .foregroundColor(Theme.textTertiary)
            }

            Button(action: { chat.newChat() }) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 26, height: 26)
                    .overlay(Rectangle().stroke(Theme.hairlineStrong, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("n", modifiers: .command)
            .help("New chat (⌘N)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if chat.messages.isEmpty {
                        emptyState
                    } else {
                        ForEach(chat.messages) { msg in
                            MessageRow(message: msg) {
                                memory.add(msg.content, tags: [msg.mode.rawValue], source: "chat")
                            }
                            .id(msg.id)
                            Rectangle()
                                .fill(Theme.hairline.opacity(0.55))
                                .frame(height: 1)
                        }
                    }

                    if chat.isThinking { thinkingRow.id(thinkingID) }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ScrollOffsetKey.self,
                            value: geo.frame(in: .named(ScrollOffsetKey.scrollNamespace)).minY
                        )
                    }
                )
            }
            .coordinateSpace(name: ScrollOffsetKey.scrollNamespace)
            .onPreferenceChange(ScrollOffsetKey.self) { value in
                Task { @MainActor in pinnedToBottom = value > -24 }
            }
            .onChange(of: chat.messages.count) { _ in
                guard pinnedToBottom else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    if let last = chat.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onChange(of: chat.isThinking) { _ in
                guard pinnedToBottom else { return }
                withAnimation(.easeOut(duration: 0.18)) { proxy.scrollTo(thinkingID, anchor: .bottom) }
            }
            .overlay(alignment: .bottomTrailing) {
                if !pinnedToBottom && !chat.messages.isEmpty {
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.18)) {
                            if let last = chat.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                            else { proxy.scrollTo(thinkingID, anchor: .bottom) }
                        }
                        pinnedToBottom = true
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.down").font(.system(size: 8, weight: .black))
                            Text("LATEST").font(Theme.caption(.bold)).tracking(0.8)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.accent)
                    }
                    .buttonStyle(.plain)
                    .padding(14)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            NexusMark(size: 46)
            VStack(spacing: 4) {
                Text("NEXUS READY")
                    .font(Theme.title(.bold))
                    .tracking(3)
                    .foregroundColor(Theme.textPrimary)
                Text("PERSISTENT CHAT + MEMORY · COPY \(identity.shortID)")
                    .font(Theme.caption())
                    .tracking(0.8)
                    .foregroundColor(Theme.textTertiary)
            }
            HStack(spacing: 6) {
                suggestion("find the failing test")
                suggestion("brainstorm demo ideas")
                suggestion("run the verifier")
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 50)
    }

    private func suggestion(_ text: String) -> some View {
        Button(action: { input = text; send() }) {
            Text(text)
                .font(Theme.caption(.medium))
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .overlay(Rectangle().stroke(Theme.hairlineStrong, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var thinkingRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "triangle.fill")
                .font(.system(size: 7, weight: .black))
                .foregroundColor(Theme.accent)
                .rotationEffect(.degrees(180))

            Text("NEXUS")
                .font(Theme.caption(.bold))
                .tracking(1)
                .foregroundColor(Theme.accent)

            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 4, height: 4)
                        .modifier(PulseModifier(index: i))
                }
            }

            Text("thinking…")
                .font(Theme.label())
                .foregroundColor(Theme.textTertiary)

            Spacer()

            Button(action: { chat.stopThinking() }) {
                Text("STOP")
                    .font(Theme.caption(.bold))
                    .tracking(0.8)
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .overlay(Rectangle().stroke(Theme.accent.opacity(0.6), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }

    private var modeBar: some View {
        HStack(spacing: 8) {
            Text("MODE")
                .font(Theme.caption(.bold))
                .tracking(1)
                .foregroundColor(Theme.textTertiary)

            ForEach(ChatStore.Message.Mode.allCases, id: \.self) { mode in
                ModeChip(mode: mode, isSelected: chat.selectedMode == mode)
                    .onTapGesture { withAnimation(.easeOut(duration: 0.1)) { chat.selectedMode = mode } }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var composer: some View {
        HStack(spacing: 8) {
            Text("OBJECTIVE")
                .font(Theme.caption(.bold))
                .tracking(1)
                .foregroundColor(Theme.textTertiary)

            TextField("", text: $input,
                      prompt: Text("inspect, build, or ask…")
                        .font(Theme.body())
                        .foregroundColor(Theme.textTertiary)
            )
            .textFieldStyle(.plain)
            .font(Theme.body())
            .foregroundColor(Theme.textPrimary)
            .focused($inputFocused)
            .onSubmit(send)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Theme.panelBG)
            .overlay(Rectangle().stroke(Theme.hairlineStrong, lineWidth: 1))

            Button(action: send) {
                Text("ENGAGE")
                    .font(Theme.caption(.bold))
                    .tracking(1.2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Theme.accent)
            }
            .buttonStyle(.plain)
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.35 : 1)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func send() {
        let text = input
        input = ""
        chat.send(text)
    }

    // MARK: - Copy info sheet

    private var copyInfoSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                NexusMark(size: 24)
                Text("THIS COPY OF NEXUS")
                    .font(Theme.title(.bold))
                    .tracking(2)
                    .foregroundColor(Theme.textPrimary)
            }

            VStack(alignment: .leading, spacing: 7) {
                infoRow("NAME", identity.info.name)
                infoRow("COPY ID", identity.info.id)
                infoRow("SHORT ID", identity.shortID)
                infoRow("CREATED", identity.info.createdAt.formatted(date: .abbreviated, time: .shortened))
                infoRow("CHATS", "\(chat.sessions.count)")
                infoRow("MEMORIES", "\(memory.count)")
                infoRow("DATA", identity.root.path)
            }
            .padding(12)
            .background(Theme.panelBG)
            .overlay(Rectangle().stroke(Theme.hairline, lineWidth: 1))

            VStack(alignment: .leading, spacing: 7) {
                Text("RENAME THIS COPY")
                    .font(Theme.caption(.bold))
                    .tracking(1)
                    .foregroundColor(Theme.textTertiary)
                TextField("Name", text: $renameText)
                    .textFieldStyle(.plain)
                    .font(Theme.body())
                    .foregroundColor(Theme.textPrimary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 8)
                    .background(Theme.raisedBG)
                    .overlay(Rectangle().stroke(Theme.accent.opacity(0.45), lineWidth: 1))
                Text("Chats and memory live per copy. Duplicate the folder and each copy keeps its own history.")
                    .font(Theme.caption())
                    .foregroundColor(Theme.textTertiary)
            }

            HStack(spacing: 10) {
                Spacer()
                Button("CLOSE") { showCopyInfo = false }
                    .font(Theme.caption(.bold))
                    .keyboardShortcut(.escape)
                    .keyboardShortcut("w", modifiers: .command)
                Button("SAVE") {
                    identity.rename(renameText)
                    showCopyInfo = false
                }
                .font(Theme.caption(.bold))
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            }
        }
        .padding(20)
        .frame(width: 450)
        .background(Theme.windowBG)
        .overlay(Rectangle().stroke(Theme.hairlineStrong, lineWidth: 1))
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(Theme.caption(.bold))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 88, alignment: .leading)
            Text(value)
                .font(Theme.label())
                .foregroundColor(Theme.textPrimary.opacity(0.9))
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Transcript row

struct MessageRow: View {
    let message: ChatStore.Message
    var onRemember: (() -> Void)?
    @State private var hovering = false

    private var isUser: Bool { message.role == .user }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                if !isUser {
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 7, weight: .black))
                        .foregroundColor(Theme.accent)
                        .rotationEffect(.degrees(180))
                }

                Text(isUser ? "YOU" : "NEXUS")
                    .font(Theme.caption(.bold))
                    .tracking(1)
                    .foregroundColor(isUser ? Theme.textSecondary : Theme.accent)

                Text("· \(message.mode.rawValue.uppercased()) · \(message.timestamp, style: .time)")
                    .font(Theme.caption())
                    .foregroundColor(Theme.textTertiary)

                Spacer(minLength: 0)

                if !isUser, hovering, let onRemember {
                    Button(action: onRemember) {
                        HStack(spacing: 4) {
                            Image(systemName: "brain").font(.system(size: 7))
                            Text("REMEMBER").font(Theme.caption(.bold)).tracking(0.5)
                        }
                        .foregroundColor(Theme.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .overlay(Rectangle().stroke(Theme.accent.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help("Save to this copy's memory")
                }
            }

            Text(message.content)
                .font(Theme.body())
                .foregroundColor(isUser ? Theme.textPrimary : Theme.textPrimary.opacity(0.95))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, isUser ? 0 : 15)
        }
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onHover { hovering = $0 }
    }
}

// MARK: - Mode chip

struct ModeChip: View {
    let mode: ChatStore.Message.Mode
    let isSelected: Bool

    var body: some View {
        Text(mode.rawValue.uppercased())
            .font(Theme.caption(.bold))
            .tracking(0.8)
            .foregroundColor(isSelected ? Theme.accent : Theme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Theme.accentWash : Color.clear)
            .overlay(
                Rectangle().stroke(isSelected ? Theme.accent : Theme.hairlineStrong, lineWidth: 1)
            )
    }
}

// MARK: - Pulsing dots for the thinking row

private struct PulseModifier: ViewModifier {
    let index: Int
    @State private var on = false

    func body(content: Content) -> some View {
        content.opacity(on ? 1 : 0.2)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.55).repeatForever().delay(Double(index) * 0.16)) {
                    on = true
                }
            }
    }
}

// MARK: - Scroll offset tracking

private struct ScrollOffsetKey: PreferenceKey {
    static let scrollNamespace = "nexusChatScroll"
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
