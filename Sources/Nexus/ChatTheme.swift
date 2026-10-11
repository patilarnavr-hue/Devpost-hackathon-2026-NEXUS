// NEXUS machine aesthetic tokens — flat black, red hierarchy, monospace, hairlines.

import SwiftUI

enum Theme {
    // MARK: Colors — pure black panels, no gradients
    static let windowBG = Color.black
    static let sidebarBG = Color(white: 0.045)
    static let panelBG = Color(white: 0.07)
    static let raisedBG = Color(white: 0.10)
    static let hairline = Color.white.opacity(0.13)
    static let hairlineStrong = Color.white.opacity(0.24)

    static let accent = Palette.accent                                   // bright red — attention
    static let accentSoft = Palette.accent.opacity(0.75)
    static let accentWash = Palette.accent.opacity(0.10)

    static let textPrimary = Color(white: 0.93)
    static let textSecondary = Color(white: 0.52)
    static let textTertiary = Color(white: 0.33)
    static let green = Color(red: 0.35, green: 0.82, blue: 0.50)
    static let amber = Color(red: 0.95, green: 0.70, blue: 0.28)

    // MARK: Type — monospace everywhere, nothing below 10pt
    static func display(_ weight: Font.Weight = .bold) -> Font {
        .system(size: 20, weight: weight, design: .monospaced)
    }
    static func title(_ weight: Font.Weight = .semibold) -> Font {
        .system(size: 13, weight: weight, design: .monospaced)
    }
    static func headline(_ weight: Font.Weight = .semibold) -> Font {
        .system(size: 12, weight: weight, design: .monospaced)
    }
    static func body(_ weight: Font.Weight = .regular) -> Font {
        .system(size: 12.5, weight: weight, design: .monospaced)
    }
    static func label(_ weight: Font.Weight = .medium) -> Font {
        .system(size: 11, weight: weight, design: .monospaced)
    }
    static func caption(_ weight: Font.Weight = .medium) -> Font {
        .system(size: 10, weight: weight, design: .monospaced)
    }
    static func mono(_ size: CGFloat = 11, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    // MARK: Metrics — square machine corners
    static let radiusCard: CGFloat = 3
    static let radiusChip: CGFloat = 2
    static let radiusField: CGFloat = 3
    static let sidebarWidth: CGFloat = 240
}

// MARK: - Flat machine pieces

struct NexusMark: View {
    var size: CGFloat = 26
    var body: some View {
        Image(systemName: "triangle.fill")
            .font(.system(size: size * 0.52, weight: .black))
            .foregroundColor(Theme.accent)
            .rotationEffect(.degrees(180))
            .frame(width: size, height: size)
            .overlay(
                Rectangle().stroke(Theme.accent.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: Theme.accent.opacity(0.45), radius: size * 0.22)
    }
}
