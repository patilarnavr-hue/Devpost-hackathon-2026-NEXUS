// NEXUS Permissions View — display and manage permissions

import SwiftUI

struct PermissionsView: View {
    @EnvironmentObject var engine: NexusEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Permissions")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(20)

            VStack(spacing: 12) {
                PermissionRow(
                    name: "File System Read",
                    description: "Read files within the workspace",
                    status: .granted,
                    risk: .low
                )
                PermissionRow(
                    name: "File System Write",
                    description: "Create and modify files within the workspace",
                    status: .granted,
                    risk: .medium
                )
                PermissionRow(
                    name: "Network Access",
                    description: "Search web and access external APIs",
                    status: .granted,
                    risk: .low
                )
                PermissionRow(
                    name: "File System Delete",
                    description: "Delete files (requires explicit approval)",
                    status: .denied,
                    risk: .high
                )
                PermissionRow(
                    name: "Calendar Access",
                    description: "Read and propose calendar events",
                    status: .granted,
                    risk: .low
                )
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(Color.black)
    }
}

enum PermissionStatus {
    case granted, denied, ask
}

enum RiskLevel {
    case low, medium, high
}

struct PermissionRow: View {
    let name: String
    let description: String
    let status: PermissionStatus
    let risk: RiskLevel

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }

            Spacer()

            HStack(spacing: 8) {
                Text(riskText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(riskColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(riskColor.opacity(0.15))
                    .cornerRadius(4)

                Text(statusText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.15))
                    .cornerRadius(4)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
    }

    private var statusText: String {
        switch status {
        case .granted: return "GRANTED"
        case .denied: return "DENIED"
        case .ask: return "ASK"
        }
    }

    private var statusColor: Color {
        switch status {
        case .granted: return Palette.seal
        case .denied: return Palette.critical
        case .ask: return Palette.activity
        }
    }

    private var riskText: String {
        switch risk {
        case .low: return "LOW"
        case .medium: return "MEDIUM"
        case .high: return "HIGH"
        }
    }

    private var riskColor: Color {
        switch risk {
        case .low: return Palette.seal
        case .medium: return Palette.activity
        case .high: return Palette.critical
        }
    }
}
