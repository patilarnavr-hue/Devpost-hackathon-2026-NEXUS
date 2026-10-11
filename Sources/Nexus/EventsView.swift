// NEXUS Events View — real-time activity timeline

import SwiftUI

struct EventsView: View {
    @EnvironmentObject var engine: NexusEngine
    @State private var mode = 0   // 0 = session timeline, 1 = live stream

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Events")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Picker("", selection: $mode) {
                    Text("SESSION").tag(0)
                    Text("LIVE").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)

                Text(countLabel)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .frame(width: 80, alignment: .trailing)
            }
            .padding(20)

            if mode == 0 {
                sessionTimeline
            } else if engine.events.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No events yet")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    Text("Events appear as NEXUS processes goals")
                        .font(.system(size: 13))
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(engine.events.reversed()) { event in
                            EventRow(event: event)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .background(Color.black)
    }

    private var countLabel: String {
        mode == 0
            ? "\(engine.activeSession?.timeline.count ?? 0) entries"
            : "\(engine.events.count) events"
    }

    // Operational memory of the active world.
    private var sessionTimeline: some View {
        let entries = (engine.activeSession?.timeline ?? []).reversed()
        return Group {
            if entries.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("This world has no history yet")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    Text("Goals, decisions and operations land here as they happen")
                        .font(.system(size: 13))
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(entries) { entry in
                            TimelineRow(entry: entry)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }
}

struct TimelineRow: View {
    let entry: SessionEntry

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: entry.t)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(timeString)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Palette.grayDim)
                .frame(width: 44, alignment: .leading)

            RoundedRectangle(cornerRadius: 2)
                .fill(barColor)
                .frame(width: 3, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.kind.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(kindColor)
                Text(entry.label)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(entry.kind == "goal" ? Palette.white : Palette.gray)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private var kindColor: Color {
        switch entry.kind {
        case "goal": return Palette.accent
        case "decision": return Palette.white
        default:
            switch entry.severity {
            case "critical", "high": return Palette.critical
            default: return Palette.grayDim
            }
        }
    }

    private var barColor: Color {
        entry.kind == "goal" ? Palette.accent : Palette.grayDim.opacity(0.7)
    }
}

struct EventRow: View {
    let event: ActivityEvent

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(severityColor)
                .frame(width: 3, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(event.type)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(severityColor)

                    if !event.workflow.isEmpty {
                        Text(event.workflow)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Text(event.timestamp, style: .time)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                }

                Text(event.message)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .lineLimit(2)

                if !event.source.isEmpty {
                    Text(event.source)
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.7))
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var severityColor: Color {
        switch event.severity {
        case "critical": return Palette.critical
        case "high": return Palette.activity
        case "normal": return Palette.accent
        case "low": return .gray
        default: return Palette.activity
        }
    }
}
