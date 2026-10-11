// NEXUS Onboarding — the Red Triangle itself walks you through the app.
// Shows once on first launch (UserDefaults), skippable.

import SwiftUI

private let guideDoneKey = "nexus.guideDone"

struct NEXUSGuide: View {
    @EnvironmentObject var engine: NexusEngine
    @State private var step = 0
    @State private var appeared = false
    let onDone: () -> Void

    private let steps: [(String, String)] = [
        ("I'M NEXUS", "Your Red Triangle companion. I live on this Mac, learn chores, and run them for you.\n\nPress ⌥Space anywhere to open my lens — talk to me, or teach me a chore."),
        ("GIVE ME A MISSION", "Type a goal below — e.g. \"organize my Downloads by file type.\"\n\nI break it into steps, execute them one by one, and verify each one with proof."),
        ("WATCH ME WORK", "Events shows every step live. A verified mission ends with a white ✓ seal — that's my guarantee, not my word."),
        ("COLLAB IN ROOMS", "The Rooms tab creates a private LAN room. Share the code (or nexus:// link) with teammates — chat plus a shared mission board."),
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()
                .onTapGesture { }   // block clicks through

            VStack(spacing: 20) {
                // the guide triangle — same silhouette as the companion
                TriangleGlyph(state: appeared ? .lock : .idle)
                    .frame(width: 54, height: 54)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.45, dampingFraction: 0.6), value: appeared)

                VStack(spacing: 10) {
                    Text(steps[step].0)
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text(steps[step].1)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Palette.gray)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 360)

                HStack(spacing: 8) {
                    ForEach(steps.indices, id: \.self) { i in
                        Circle()
                            .fill(i == step ? Palette.accent : Palette.grayDim)
                            .frame(width: 6, height: 6)
                            .animation(.easeOut(duration: 0.15), value: step)
                    }
                }

                HStack(spacing: 10) {
                    Button("SKIP") { finish() }
                        .keyboardShortcut(.escape, modifiers: [])
                        .foregroundColor(Palette.grayDim)
                        .buttonStyle(.plain)

                    Spacer()

                    Button(step == steps.count - 1 ? "LET'S GO" : "NEXT") {
                        if step == steps.count - 1 {
                            finish()
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { step += 1 }
                        }
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 8)
                    .background(Palette.accent)
                    .cornerRadius(6)
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: 360)
            }
            .padding(30)
            .frame(width: 460)
            .background(Palette.background)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.accent.opacity(0.5), lineWidth: 1))
            .scaleEffect(appeared ? 1 : 0.92)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: appeared)
        }
        .transition(.opacity)
        .onAppear { appeared = true }
    }

    private func finish() {
        withAnimation(.easeOut(duration: 0.2)) { appeared = false }
        UserDefaults.standard.set(true, forKey: guideDoneKey)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onDone() }
    }
}

// MARK: - The triangle glyph (mirrors the companion + app icon)

enum TriangleGlowState { case idle, lock }

struct TriangleGlyph: View {
    var state: TriangleGlowState
    @State private var breathe = false
    @State private var spin = false

    var body: some View {
        ZStack {
            // aura
            Circle()
                .stroke(Palette.accent.opacity(0.25), lineWidth: 0.8)
                .frame(width: 50, height: 50)
                .scaleEffect(breathe ? 1 : 1.08)
                .opacity(breathe ? 1 : 0.6)
            // dashed shell
            TriangleShape()
                .stroke(Palette.accent.opacity(0.75), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .frame(width: 46, height: 40)
                .rotationEffect(.degrees(spin ? 360 : 0))
            // body
            TriangleShape()
                .fill(
                    LinearGradient(colors: [Palette.accent, Palette.critical],
                                   startPoint: .top, endPoint: .bottom)
                )
                .frame(width: 32, height: 28)
                .shadow(color: Palette.accent.opacity(0.8), radius: 8)
            // core
            TriangleShape()
                .fill(Color(red: 1, green: 0.88, blue: 0.82))
                .frame(width: 12, height: 10)
        }
        .scaleEffect(state == .lock ? 1.08 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: state)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { breathe = true }
            withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) { spin = true }
        }
    }
}

struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY - 2))
        p.addLine(to: CGPoint(x: rect.minX + 2, y: rect.minY + 2))
        p.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.minY + 2))
        p.closeSubpath()
        return p
    }
}
