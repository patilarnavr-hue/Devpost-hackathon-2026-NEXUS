// NEXUS Mission Dashboard — active mission, schedule, history, artifacts.
// Typographic rows on black. Red marks what is live; gray is context.

import SwiftUI
import AppKit

struct DashboardView: View {
    @EnvironmentObject var engine: NexusEngine

    @State private var showAdd = false
    @State private var newName = ""
    @State private var newTrigger = "cron"
    @State private var newSchedule = ""
    @State private var newGoal = ""

    private var dash: DashboardData { engine.dashboard ?? DashboardData() }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    activeMissionSection
                    scheduledSection
                    historySection
                    artifactsSection
                }
                .padding(.bottom, 24)
            }
        }
        .background(Palette.background)
        .onAppear { engine.requestDashboard() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Dashboard")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            Text("\(dash.scheduled.count) SCHEDULED · \(dash.history.count) RUNS · \(dash.artifacts.count) ARTIFACTS")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Palette.grayDim)
                .padding(.leading, 10)
            Spacer()
            Button(action: { engine.requestDashboard() }) {
                Text("REFRESH")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Palette.gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
    }

    // MARK: - Section scaffolding

    private func sectionLabel(_ title: String, live: Bool = false) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(live ? Palette.accent : Palette.grayDim)
            Rectangle()
                .fill((live ? Palette.activity : Color.white.opacity(0.08)))
                .frame(height: 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 8)
    }

    private var hairline: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
            .padding(.horizontal, 20)
    }

    // MARK: - Active mission

    @ViewBuilder private var activeMissionSection: some View {
        sectionLabel("ACTIVE MISSION", live: engine.missionRunning)

        if let mission = engine.mission, engine.missionRunning {
            VStack(alignment: .leading, spacing: 8) {
                Text(mission.objective)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(Palette.white)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 16) {
                    statChip("PHASE", (mission.phase ?? "—").uppercased(), Palette.activity)
                    statChip("STEP", mission.stepsTotal > 0
                             ? "\(min(mission.stepsDone + 1, mission.stepsTotal))/\(mission.stepsTotal)"
                             : "—", Palette.white)
                    statChip("ETA", etaString(mission.etaMs), Palette.white)
                    statChip("STATE", engine.state.rawValue, Palette.activity)
                }

                progressBar

                if !mission.step.isEmpty {
                    HStack(spacing: 6) {
                        Text("▸")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Palette.accent)
                        Text(mission.step)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Palette.gray)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        } else {
            emptyState("No active mission", "Submit a goal from Overview")
                .padding(.bottom, 8)
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 2)
                Rectangle()
                    .fill(Palette.accent)
                    .frame(width: max(2, geo.size.width * clampedProgress), height: 2)
            }
        }
        .frame(height: 2)
        .animation(.easeOut(duration: 0.3), value: clampedProgress)
    }

    private var clampedProgress: Double {
        if engine.mission?.stepsTotal ?? 0 > 0,
           let m = engine.mission {
            return Double(m.stepsDone) / Double(m.stepsTotal)
        }
        return min(max(engine.progress, 0), 1)
    }

    private func statChip(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(Palette.grayDim)
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
                .lineLimit(1)
        }
    }

    private func etaString(_ ms: Int) -> String {
        guard ms > 0 else { return "—" }
        let s = ms / 1000
        if s < 90 { return "~\(s)s" }
        return "~\(s / 60)m"
    }

    // MARK: - Scheduled

    private var scheduledSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                sectionLabel("SCHEDULED")
                Spacer()
                Button(action: { showAdd.toggle() }) {
                    Text(showAdd ? "CANCEL" : "+ ADD")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(showAdd ? Palette.gray : Palette.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke((showAdd ? Palette.gray : Palette.accent).opacity(0.5), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.trailing, 20)
                .padding(.top, 22)
            }

            if showAdd { addForm }

            if dash.scheduled.isEmpty {
                emptyState("Nothing scheduled", "cron, webhook, or event triggers")
                    .padding(.bottom, 8)
            } else {
                ForEach(dash.scheduled) { mission in
                    scheduledRow(mission)
                    hairline
                }
            }
        }
    }

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                formField("NAME", text: $newName)
                    .frame(width: 160)
                Picker("", selection: $newTrigger) {
                    Text("CRON").tag("cron")
                    Text("WEBHOOK").tag("webhook")
                    Text("EVENT").tag("event")
                }
                .labelsHidden()
                .frame(width: 120)
                formField(newTrigger == "cron" ? "CRON  0 9 * * *"
                          : newTrigger == "webhook" ? "PATH  /deploy" : "EVENT  type",
                          text: $newSchedule)
            }
            HStack(spacing: 12) {
                formField("GOAL TEXT", text: $newGoal)
                Button(action: submitNew) {
                    Text("ADD")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Palette.background)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(canAdd ? Palette.accent : Palette.grayDim)
                }
                .buttonStyle(.plain)
                .disabled(!canAdd)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private func formField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField("", text: text, prompt: Text(placeholder)
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(Palette.grayDim))
            .textFieldStyle(.plain)
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(Palette.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
    }

    private var canAdd: Bool {
        !newName.trimmingCharacters(in: .whitespaces).isEmpty
            && !newSchedule.trimmingCharacters(in: .whitespaces).isEmpty
            && !newGoal.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func submitNew() {
        let payload: [String: Any] = [
            "id": "\(newTrigger)-\(Date().timeIntervalSince1970)",
            "name": newName.trimmingCharacters(in: .whitespaces),
            "trigger_type": newTrigger,
            "schedule": newSchedule.trimmingCharacters(in: .whitespaces),
            "goal_text": newGoal.trimmingCharacters(in: .whitespaces),
            "intent": "mission",
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let note = String(data: data, encoding: .utf8) {
            engine.sendControl("schedule_add", note: note)
        }
        newName = ""; newSchedule = ""; newGoal = ""
        showAdd = false
    }

    private func scheduledRow(_ mission: ScheduledMissionData) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(mission.enabled ? Palette.accent : Palette.grayDim)
                .frame(width: 6, height: 6)

            Text(mission.name.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(mission.enabled ? Palette.white : Palette.gray)
                .lineLimit(1)

            Text(mission.triggerType.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(Palette.grayDim)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .overlay(RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1))

            Text(mission.schedule)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Palette.activity)
                .lineLimit(1)

            Spacer()

            if let next = mission.nextRun, mission.enabled {
                Text("NEXT \(next, format: .dateTime.hour().minute())")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Palette.gray)
            }
            if mission.runCount > 0 {
                Text("×\(mission.runCount)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Palette.grayDim)
            }

            Button(action: {
                engine.sendControl("schedule_enable",
                                  note: "\(mission.id):\(mission.enabled ? "false" : "true")")
            }) {
                Text(mission.enabled ? "ON" : "OFF")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(mission.enabled ? Palette.accent : Palette.grayDim)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .overlay(RoundedRectangle(cornerRadius: 2)
                        .stroke((mission.enabled ? Palette.accent : Palette.grayDim).opacity(0.5), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help(mission.enabled ? "Disable" : "Enable")

            Button(action: { engine.sendControl("schedule_remove", note: mission.id) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Palette.grayDim)
            }
            .buttonStyle(.plain)
            .help("Remove")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 9)
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("MISSION HISTORY")

            if dash.history.isEmpty {
                emptyState("No runs yet", "completed goals appear here")
                    .padding(.bottom, 8)
            } else {
                ForEach(dash.history) { entry in
                    historyRow(entry)
                    hairline
                }
            }
        }
    }

    private func historyRow(_ entry: MissionHistoryEntry) -> some View {
        HStack(spacing: 12) {
            Text(entry.t, format: .dateTime.hour().minute())
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Palette.grayDim)
                .frame(width: 42, alignment: .leading)

            Text(entry.label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Palette.white)
                .lineLimit(1)

            Spacer()

            if !entry.intent.isEmpty {
                Text(entry.intent.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(Palette.activity)
            }
            Text(entry.sessionName)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Palette.grayDim)
                .lineLimit(1)
                .frame(maxWidth: 160, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 7)
    }

    // MARK: - Artifacts

    private var artifactsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("ARTIFACTS")

            if dash.artifacts.isEmpty {
                emptyState("No artifacts", "mission reports are written to reports/")
                    .padding(.bottom, 8)
            } else {
                ForEach(dash.artifacts) { artifact in
                    artifactRow(artifact)
                    hairline
                }
            }
        }
    }

    private func artifactRow(_ artifact: ArtifactInfo) -> some View {
        HStack(spacing: 12) {
            Image(systemName: artifact.name.hasSuffix(".zip") ? "archivebox" : "doc.text")
                .font(.system(size: 11))
                .foregroundColor(Palette.activity)
                .frame(width: 14)

            Text(artifact.name)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Palette.white)
                .lineLimit(1)

            Spacer()

            Text(byteString(artifact.size))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Palette.grayDim)
            Text(artifact.modified, format: .dateTime.hour().minute())
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Palette.grayDim)

            Button(action: { reveal(artifact) }) {
                Text("REVEAL")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(Palette.gray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .overlay(RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 7)
    }

    private func reveal(_ artifact: ArtifactInfo) {
        guard !artifact.path.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: artifact.path)])
    }

    private func byteString(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
    }

    private func emptyState(_ title: String, _ hint: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Palette.gray)
            Text(hint)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Palette.grayDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}
