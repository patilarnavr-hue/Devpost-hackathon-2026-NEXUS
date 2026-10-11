// NEXUS Boot Sequence — two vertical lines split from the center, elongating
// as they travel outward, then park as big lines with margins at the edges.
// Played forward on launch, reversed on close.

import SwiftUI

struct BootAnimationView: View {
    var reversed: Bool = false
    var duration: Double = 1.8
    var onDone: () -> Void = {}

    @State private var start = Date()
    @State private var fired = false

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let elapsed = timeline.date.timeIntervalSince(start)
                let raw = min(1.0, max(0.0, elapsed / duration))
                let p = reversed ? 1.0 - raw : raw
                draw(ctx: &ctx, size: size, p: p)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            start = Date()
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                if !fired { fired = true; onDone() }
            }
        }
    }

    // MARK: - Easing

    private func easeOutCubic(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
    private func easeInOut(_ x: Double) -> Double {
        x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
    }

    // MARK: - Draw (p = 0 → centre/dot, p = 1 → world revealed)

    private func draw(ctx: inout GraphicsContext, size: CGSize, p: Double) {
        let w = Double(size.width), h = Double(size.height)
        let cx = w / 2, cy = h / 2
        let edgeX: Double = 12.0
        let span = cx - edgeX

        // Parked line geometry — 40px margins top and bottom (blank space
        // where the ambient edge lines will later drift on the Y axis).
        let margin: Double = 40.0
        let targetH = h - 2 * margin

        // ── black field: opaque while lines travel, lifts as they park ──
        let blackA: Double
        if p < 0.45 { blackA = 1.0 } else { blackA = max(0.0, 1.0 - (p - 0.45) / 0.20) }
        if blackA > 0.001 {
            var field = Path()
            field.addRect(CGRect(x: 0, y: 0, width: w, height: h))
            ctx.fill(field, with: .color(Color.black.opacity(blackA)))
        }

        let travelP = min(1.0, p / 0.45)

        // Lines elongate as they travel — a dot at the centre becomes a
        // full-parked-height line exactly when they reach the edges.
        let h0 = targetH * easeOutCubic(travelP)

        for side in [-1.0, 1.0] {
            let x = cx + side * span * easeInOut(travelP)
            drawBigLine(ctx: &ctx, x: x, height: h0, dir: side,
                        centerY: cy, alpha: 1.0)
        }

        // ── centre mark while the lines are still leaving ──
        let dotAlpha = max(0.0, 1.0 - travelP * 1.6)
        if dotAlpha > 0.01 {
            ctx.fill(
                Path(ellipseIn: CGRect(x: cx - 3, y: cy - 3, width: 6, height: 6)),
                with: .color(Color.white.opacity(dotAlpha))
            )
        }
    }

    private func drawBigLine(ctx: inout GraphicsContext, x: Double, height: Double,
                             dir: Double, centerY: Double, alpha: Double) {
        guard alpha > 0.01, height > 2 else { return }
        let topY = centerY - height / 2
        let botY = centerY + height / 2

        var spine = Path()
        spine.move(to: CGPoint(x: x, y: topY))
        spine.addLine(to: CGPoint(x: x, y: botY))
        ctx.stroke(spine, with: .color(Palette.accent.opacity(alpha)), lineWidth: 2)

        // short slanted ticks at each corner, pointing away from centre
        let tl = 12.0
        var t1 = Path()
        t1.move(to: CGPoint(x: x, y: topY))
        t1.addLine(to: CGPoint(x: x + tl * dir, y: topY - tl))
        ctx.stroke(t1, with: .color(Color.white.opacity(alpha * 0.9)), lineWidth: 1.4)
        var t2 = Path()
        t2.move(to: CGPoint(x: x, y: botY))
        t2.addLine(to: CGPoint(x: x + tl * dir, y: botY + tl))
        ctx.stroke(t2, with: .color(Color.white.opacity(alpha * 0.9)), lineWidth: 1.4)
    }
}
