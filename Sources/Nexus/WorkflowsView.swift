// NEXUS Workflows View — display current plan and workflow status

import SwiftUI

struct WorkflowsView: View {
    @EnvironmentObject var engine: NexusEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Workflows")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(20)

            if let plan = engine.plan {
                PlanView(plan: plan)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No active workflow")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    Text("Submit a goal to start a workflow")
                        .font(.system(size: 13))
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.black)
    }
}

struct PlanView: View {
    let plan: PlanData

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(plan.objective)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    HStack {
                        Text("Plan: \(plan.id)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.gray)
                        Spacer()
                        Text(plan.status)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Palette.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Palette.accent.opacity(0.15))
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 20)

                ForEach(plan.steps) { step in
                    PlanStepRow(step: step)
                }
            }
            .padding(.bottom, 20)
        }
    }
}

struct PlanStepRow: View {
    let step: PlanStepData

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 28, height: 28)
                Image(systemName: statusIcon)
                    .font(.system(size: 12))
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(step.objective)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)

                HStack(spacing: 12) {
                    Label(step.tool, systemImage: "wrench")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)

                    Label(step.risk, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 11))
                        .foregroundColor(riskColor)
                }

                if !step.expectedResult.isEmpty {
                    Text("Expected: \(step.expectedResult)")
                        .font(.system(size: 11))
                        .foregroundColor(.gray.opacity(0.7))
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private var statusColor: Color {
        switch step.status {
        case "completed": return Palette.seal
        case "in_progress": return Palette.accent
        case "failed": return Palette.critical
        case "skipped": return .gray
        default: return Palette.activity
        }
    }

    private var statusIcon: String {
        switch step.status {
        case "completed": return "checkmark"
        case "in_progress": return "gear"
        case "failed": return "xmark"
        case "skipped": return "forward"
        default: return "clock"
        }
    }

    private var riskColor: Color {
        switch step.risk {
        case "high": return Palette.critical
        case "medium": return Palette.activity
        default: return Palette.seal
        }
    }
}
