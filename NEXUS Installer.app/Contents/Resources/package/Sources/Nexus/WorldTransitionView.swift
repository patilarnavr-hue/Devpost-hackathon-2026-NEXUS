// NEXUS World Transition — collapse → scan → resolve.
// Played when Nexus changes which world it is looking at.

import SwiftUI

struct WorldTransitionView: View {
    let transition: WorldTransition

    private let duration: Double = 1.3

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                draw(ctx: &ctx, size: size, now: timeline.date)
            }
        }
        .allowsHitTesting(false)
    }

    private func draw(ctx: inout GraphicsContext, size: CGSize, now: Date) {
        let p = min(1.0, max(0.0, now.timeIntervalSince(transition.start) / duration))
        let w = Double(size.width), h = Double(size.height)
        let cx = w / 2, cy = h / 2
        let maxDim = max(w, h)

        // ── dim field: content folds away, then resolves ──
        let alpha: Double
        if p < 0.30 { alpha = (p / 0.30) * 0.95 }
        else if p < 0.62 { alpha = 0.95 }
        else { alpha = 0.95 * max(0.0, 1.0 - (p - 0.62) / 0.34) }
        var dimRect = Path()
        dimRect.addRect(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.fill(dimRect, with: .color(Color.black.opacity(alpha)))

        // ── collapse: world folds toward the core ──
        if p < 0.52 {
            let fold = min(1.0, p / 0.38)
            let fade = max(0.0, 1.0 - max(0.0, p - 0.38) / 0.14)
            for i in 0..<16 {
                let ang = Double(i) / 16 * .pi * 2
                let inner = (maxDim * 0.06) + (1 - fold) * (maxDim * 0.44)
                let outer = maxDim * 0.85
                var line = Path()
                line.move(to: CGPoint(x: cx + cos(ang) * inner, y: cy + sin(ang) * inner))
                line.addLine(to: CGPoint(x: cx + cos(ang) * outer, y: cy + sin(ang) * outer))
                ctx.stroke(line,
                           with: .color(Palette.accent.opacity(0.45 * fade * (1 - fold * 0.4))),
                           lineWidth: 1)
            }
            // shrinking core ring
            let ringR = maxDim * 0.30 * (1 - fold * 0.85)
            if ringR > 3 {
                ctx.stroke(Path(ellipseIn: CGRect(x: cx - ringR, y: cy - ringR,
                                                  width: ringR * 2, height: ringR * 2)),
                           with: .color(Palette.accent.opacity(0.7 * fade)),
                           lineWidth: 1.4)
            }
        }

        // ── scan: the pass that reconfigures the core ──
        if p > 0.30 && p < 0.70 {
            let s = (p - 0.30) / 0.40
            let x = s * w
            let band = CGRect(x: x - 46, y: 0, width: 92, height: h)
            var bandPath = Path()
            bandPath.addRect(band)
            ctx.fill(bandPath, with: .color(Palette.accent.opacity(0.10 * sin(s * .pi))))
            var scanLine = Path()
            scanLine.move(to: CGPoint(x: x, y: 0))
            scanLine.addLine(to: CGPoint(x: x, y: h))
            ctx.stroke(scanLine,
                       with: .color(Palette.accent.opacity(0.9 * sin(s * .pi) + 0.1)),
                       lineWidth: 1.6)
            // horizontal hairline through the core
            var hair = Path()
            hair.move(to: CGPoint(x: 0, y: cy))
            hair.addLine(to: CGPoint(x: w, y: cy))
            ctx.stroke(hair, with: .color(Color.white.opacity(0.20)), lineWidth: 0.8)
        }

        // ── resolve: new world settles ──
        if p >= 0.62 {
            let r = min(1.0, (p - 0.62) / 0.38)
            let ringR = maxDim * 0.05 + r * maxDim * 0.26
            ctx.stroke(Path(ellipseIn: CGRect(x: cx - ringR, y: cy - ringR,
                                              width: ringR * 2, height: ringR * 2)),
                       with: .color(Palette.accent.opacity(0.5 * (1 - r))),
                       lineWidth: 1.2)
        }

        // ── labels: where Nexus was, where it is going ──
        let fromAlpha = max(0.0, 1.0 - p / 0.34)
        if fromAlpha > 0.01 && !transition.from.isEmpty {
            ctx.draw(Text(transition.from.uppercased())
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.white.opacity(fromAlpha)),
                     at: CGPoint(x: cx, y: cy - 6))
        }
        let toAlpha = p > 0.56 ? min(1.0, (p - 0.56) / 0.24) : 0
        if toAlpha > 0.01 && !transition.to.isEmpty {
            ctx.draw(Text(transition.to.uppercased())
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(Palette.accent.opacity(toAlpha)),
                     at: CGPoint(x: cx, y: cy - 6))
        }
        if p > 0.24 && p < 0.74 {
            let noteAlpha = sin(min(1.0, (p - 0.24) / 0.5) * .pi)
            ctx.draw(Text("RECONFIGURING WORLD")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.55 * noteAlpha)),
                     at: CGPoint(x: cx, y: cy + 18))
        }
    }
}
