// Installer panes — welcome, settings, progress, done.

import SwiftUI

// MARK: - Welcome

struct WelcomePane: View {
    @ObservedObject var model: InstallerModel
    let accent: Color

    var body: some View {
        PaneView(
            title: "Set up NEXUS",
            subtitle: "Everything runs locally on this Mac — no cloud, no API keys.",
            accent: accent
        ) {
            VStack(alignment: .leading, spacing: 10) {
                featureRow(
                    "cpu",
                    "Ollama runtime",
                    "Local LLM server (llama3.2:3b) with tool-calling. Downloads ~200 MB, pulled ~2 GB."
                )
                featureRow(
                    "square.stack.3d.up",
                    "NEXUS app",
                    "Swift 6 + SwiftUI interface. Chats and memory persist, isolated per copy."
                )
                featureRow(
                    "triangle.fill",
                    "Red Triangle",
                    "Cursor-following companion with ⌥Space command lens. Runs permanently, independently."
                )
                featureRow(
                    "checkmark.seal",
                    "Verifier",
                    "Real exit-code verification — only exit 0 counts as success."
                )

                HStack(spacing: 8) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 10))
                    Text("Requires ~3 GB disk · macOS 14 or later · internet for first install")
                        .font(.system(size: 9, design: .monospaced))
                }
                .foregroundColor(accent.opacity(0.75))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(accent.opacity(0.08))
                .cornerRadius(5)
            }
        }
    }

    private func featureRow(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(accent)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                Text(detail)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .cornerRadius(5)
    }
}

// MARK: - Settings

struct SettingsPane: View {
    @ObservedObject var model: InstallerModel
    let accent: Color

    var body: some View {
        PaneView(
            title: "Preferences",
            subtitle: "You can change these later by re-running the installer.",
            accent: accent
        ) {
            VStack(alignment: .leading, spacing: 16) {
                // Model picker
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("MODEL")
                    Picker("", selection: $model.settings.model) {
                        ForEach(InstallerModel.Settings.models, id: \.self) { m in
                            Text("\(m)  ·  \(m == "llama3.2:3b" ? "2.0 GB · recommended" : "1.3 GB · faster")").tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    Text("This Mac has 8 GB RAM; the 3B model fits. The 1B fallback is faster but weaker.")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }

                Divider().background(Color.white.opacity(0.12))

                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("AUTOMATION")
                    toggleRow(
                        "Pull the 1B fallback too",
                        "Gives NEXUS a second model if the primary is too slow",
                        $model.settings.pullBothModels
                    )
                    toggleRow(
                        "Run Red Triangle permanently",
                        "Registers a login item so the triangle follows your cursor at every boot, independent of NEXUS",
                        $model.settings.autoRunTriangle
                    )
                    toggleRow(
                        "Launch after install",
                        "Open NEXUS and the Red Triangle when setup completes",
                        $model.settings.launchAfterInstall
                    )
                    toggleRow(
                        "Add nexu terminal command",
                        "Creates /usr/local/bin/nexus (falls back to ~/.local/bin)",
                        $model.settings.createDesktopAlias
                    )
                    toggleRow(
                        "Check Accessibility permission",
                        "The triangle needs this to drive the cursor; you will be prompted in System Settings",
                        $model.settings.grantAccessibilityHint
                    )
                }

                Divider().background(Color.white.opacity(0.12))

                // Detected paths
                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel("DETECTED")
                    pathRow("Installation", InstallerModel.Paths.resolve().submissionRoot.path)
                    pathRow("NEXUS app", InstallerModel.Paths.resolve().nexusApp.path)
                    pathRow("Red Triangle", InstallerModel.Paths.resolve().triangleApp.path)
                }
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundColor(accent.opacity(0.8))
    }

    private func toggleRow(_ title: String, _ detail: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                Text(detail)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .toggleStyle(.checkbox)
    }

    private func pathRow(_ label: String, _ path: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 88, alignment: .leading)
            Text(path)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

// MARK: - Install progress

struct InstallPane: View {
    @ObservedObject var model: InstallerModel
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Progress header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(model.finished ? (model.failed ? "Install incomplete" : "Install complete") : "Setting up NEXUS")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(model.failed ? Color.red : .white)
                    Spacer()
                    Text("\(Int(model.progress * 100))%")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(accent)
                }

                ProgressView(value: model.progress)
                    .progressViewStyle(.linear)
                    .tint(accent)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)

            HStack(spacing: 0) {
                // Task list
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(Array(model.tasks.enumerated()), id: \.element.id) { i, task in
                            taskRow(task)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 9)
                                .background(
                                    task.state == .running ? accent.opacity(0.09) : Color.clear
                                )
                        }
                    }
                    .padding(.top, 8)
                }
                .frame(width: 280)

                // Log console
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("OUTPUT")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.04))

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 3) {
                                ForEach(model.log) { line in
                                    Text("[\(line.time, formatter: timeFormatter)] \(line.text)")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(color(for: line.kind))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .textSelection(.enabled)
                                        .id(line.id)
                                }
                            }
                            .padding(12)
                        }
                        .onChange(of: model.log.count) {
                            if let last = model.log.last { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
                .background(Color.black.opacity(0.35))
            }
        }
    }

    private func taskRow(_ task: InstallerModel.TaskItem) -> some View {
        HStack(spacing: 9) {
            ZStack {
                Circle()
                    .stroke(color(for: task.state), lineWidth: 1.4)
                    .frame(width: 13, height: 13)
                if task.state == .done {
                    Circle().fill(color(for: .done)).frame(width: 6, height: 6)
                } else if task.state == .running {
                    Circle().fill(color(for: .running)).frame(width: 6, height: 6)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(.system(size: 11, weight: task.state == .running ? .semibold : .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(task.state == .pending ? 0.4 : 0.9))
                Text(task.detail)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
                    .lineLimit(1)
            }
            Spacer()
        }
    }

    private func color(for kind: InstallerModel.LogLine.Kind) -> Color {
        switch kind {
        case .info: return .white.opacity(0.6)
        case .ok: return Color.green.opacity(0.85)
        case .warn: return .orange.opacity(0.9)
        case .error: return .red
        case .cmd: return accent.opacity(0.8)
        }
    }

    private func color(for state: InstallerModel.TaskItem.State) -> Color {
        switch state {
        case .pending: return .white.opacity(0.22)
        case .running: return accent
        case .done: return .green.opacity(0.9)
        case .failed: return .red
        case .skipped: return .white.opacity(0.3)
        }
    }

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }
}

// MARK: - Done

struct DonePane: View {
    @ObservedObject var model: InstallerModel
    let accent: Color

    var body: some View {
        PaneView(
            title: "You're all set",
            subtitle: "NEXUS is installed on this Mac. Everything below runs locally.",
            accent: accent
        ) {
            VStack(alignment: .leading, spacing: 10) {
                commandCard("nexus", "Launch the NEXUS app")
                commandCard("nexus-triangle", "Launch the Red Triangle on its own")
                commandCard("⌥Space", "Open the triangle's command lens anywhere")
                commandCard("⌘N / ⌘K", "New chat / clear — chats and memory persist per copy")

                VStack(alignment: .leading, spacing: 6) {
                    label("RED TRIANGLE · PERMANENT")
                    Text("Registered as a login item, so it starts at every boot and runs independently of the NEXUS window. Close either one — the other keeps working. Stop it from the triangle's menu bar icon.")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.55))
                }
                .padding(12)
                .background(accent.opacity(0.08))
                .cornerRadius(5)

                if model.failed {
                    VStack(alignment: .leading, spacing: 4) {
                        label("NOTICE")
                        Text(model.errorMessage)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.red.opacity(0.9))
                    }
                    .padding(12)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(5)
                }
            }
        }
    }

    private func commandCard(_ command: String, _ description: String) -> some View {
        HStack(spacing: 10) {
            Text(command)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.06))
                .cornerRadius(3)
            Text(description)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundColor(accent.opacity(0.8))
    }
}
