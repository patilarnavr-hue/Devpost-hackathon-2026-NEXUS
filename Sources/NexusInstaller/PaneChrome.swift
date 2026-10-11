// InstallerView — professional multi-step setup wizard.

import SwiftUI

struct InstallerView: View {
    @StateObject private var model = InstallerModel()
    @Environment(\.colorScheme) private var scheme

    private let accent = Color(red: 1.0, green: 0.23, blue: 0.19)
    private let bg = Color(white: 0.06)
    private let panel = Color(white: 0.10)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Divider().background(Color.white.opacity(0.12))

                Group {
                    switch model.step {
                    case .welcome: WelcomePane(model: model, accent: accent)
                    case .settings: SettingsPane(model: model, accent: accent)
                    case .install: InstallPane(model: model, accent: accent)
                    case .done: DonePane(model: model, accent: accent)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider().background(Color.white.opacity(0.12))
                bottomBar
            }
        }
        .frame(width: 720, height: 520)
        .preferredColorScheme(.dark)
#if os(macOS)
        .toolbar { Button(action: { NSApp.terminate(nil) }) { Image(systemName: "xmark.circle.fill").foregroundColor(.white.opacity(0.4)) } }
#endif
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(accent)
                    .frame(width: 34, height: 34)
                Image(systemName: "triangle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .rotationEffect(.degrees(180))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("NEXUS")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text("EvoHacks 2026 · AI for Automation")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.45))
            }

            Spacer()

            // Step indicator
            HStack(spacing: 6) {
                ForEach(Array(Step.allCases.enumerated()), id: \.element) { i, step in
                    Circle()
                        .fill(dotColor(for: step, index: i))
                        .frame(width: 6, height: 6)
                    if i < Step.allCases.count - 1 {
                        Rectangle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 14, height: 1)
                    }
                }
            }

            Text(model.step.title.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(accent.opacity(0.85))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(accent.opacity(0.12))
                .cornerRadius(3)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func dotColor(for step: Step, index: Int) -> Color {
        let current = model.step.rawValue
        if index < current { return accent }
        if index == current { return accent.opacity(0.75) }
        return Color.white.opacity(0.2)
    }

    // MARK: - Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        HStack(spacing: 10) {
            if model.step == .settings {
                Button("Back") { model.step = .welcome }
            }
            Spacer()

            switch model.step {
            case .welcome:
                Button("Continue") { model.step = .settings }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
            case .settings:
                Button("Install") { model.startInstall() }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .keyboardShortcut(.return)
            case .install:
                if model.finished && !model.failed {
                    Button("Finish") { model.finish() }
                        .buttonStyle(.borderedProminent)
                        .tint(accent)
                        .keyboardShortcut(.return)
                } else if model.failed {
                    Button("Back to Preferences") { model.step = .settings }
                } else {
                    ProgressView().scaleEffect(0.6).frame(width: 18, height: 18)
                    Text("Working…")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
            case .done:
                Button("Done") { NSApp.terminate(nil) }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Pane chrome

struct PaneView<Content: View>: View {
    let title: String
    let subtitle: String
    let accent: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }

            ScrollView(showsIndicators: false) {
                content()
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
