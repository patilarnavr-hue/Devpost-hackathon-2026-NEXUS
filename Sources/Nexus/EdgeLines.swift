// NEXUS Edge Lines — ambient decoration on the left/right gutters.
// Starts as the two big parked lines from the boot sequence (seamless handoff),
// then after a short hold each side randomly morphs between 1 big line and
// 2 small lines, drifting gently on the Y axis within the margins.

import SwiftUI

struct EdgeLinesView: View {
    @ObservedObject private var appState = AppState.shared
    @State private var t0 = Date()

    struct Seg {
        var y: Double   // centre y
        var h: Double   // height (0 = collapsed)
    }

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let w = Double(size.width)
                let h = Double(size.height)
                let t = tl.date.timeIntervalSince(t0)
                let forced = (appState.phase != .running)
                render(&ctx, w: w, h: h, t: t, forced: forced)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Deterministic noise

    private func rnd(_ seed: Double) -> Double {
        let v = sin(seed * 12.9898 + 78.233) * 43758.5453
        return v - v.rounded(.down)           // always in [0, 1)
    }

    private func easeInOut(_ x: Double) -> Double {
        x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
    }

    private func lerp(_ a: Double, _ b: Double, _ p: Double) -> Double {
        a + (b - a) * p
    }

    private func lerpSeg(_ a: Seg, _ b: Seg, _ p: Double) -> Seg {
        Seg(y: lerp(a.y, b.y, p), h: lerp(a.h, b.h, p))
    }

    // MARK: - Configurations

    /// The initial big parked line — identical geometry to the boot lines
    /// (40px top/bottom margins) so the handoff is invisible.
    private func initialSegs(h: Double) -> (Seg, Seg) {
        (Seg(y: h / 2, h: h - 80.0), Seg(y: h / 2, h: 0))
    }

    /// Random configuration for one side in cycle `n`.
    /// ~45% chance of one big line, otherwise two small lines.
    private func config(side: Double, n: Int, h: Double) -> (Seg, Seg) {
        let base = Double(n) * 17.31 + side * 5.77
        let margin = 40.0

        if rnd(base + 1.0) < 0.45 {
            // one big line
            let jitterY = (rnd(base + 2.0) - 0.5) * 60.0
            var hh = (h - 80.0) - rnd(base + 3.0) * 70.0
            var cy = h / 2 + jitterY
            let lo = margin + hh / 2
            let hi = h - margin - hh / 2
            if lo > hi {
                hh = h - 2 * margin
                cy = h / 2
            } else {
                cy = min(max(cy, lo), hi)
            }
            return (Seg(y: cy, h: hh), Seg(y: cy, h: 0))
        } else {
            // two small lines, one in the upper half, one in the lower half
            let segH = h * 0.16 + rnd(base + 4.0) * 50.0
            let lo = margin + segH / 2
            let hi = h - margin - segH / 2
            let y0 = min(max(h * 0.18 + (rnd(base + 5.0) - 0.5) * h * 0.24, lo), hi)
            let y1 = min(max(h * 0.78 + (rnd(base + 6.0) - 0.5) * h * 0.24, lo), hi)
            return (Seg(y: y0, h: segH), Seg(y: y1, h: segH))
        }
    }

    // MARK: - Render

    private func render(_ ctx: inout GraphicsContext, w: Double, h: Double,
                        t: Double, forced: Bool) {
        let margin = 40.0
        let leftX = 12.0
        let rightX = w - 12.0

        var segsL = initialSegs(h: h)
        var segsR = initialSegs(h: h)

        if !forced {
            let hold: Double = 3.0        // big parked lines stay for 3s
            let cycleDur: Double = 4.0    // one config per 4s
            let morphDur: Double = 1.2    // transition takes 1.2s

            if t >= hold {
                let tt = t - hold
                let n = Int(tt / cycleDur) + 1
                let tp = tt - Double(n - 1) * cycleDur
                let e = easeInOut(min(1.0, tp / morphDur))

                let prevL = (n == 1) ? initialSegs(h: h) : config(side: -1, n: n - 1, h: h)
                let nextL = config(side: -1, n: n, h: h)
                let prevR = (n == 1) ? initialSegs(h: h) : config(side: 1, n: n - 1, h: h)
                let nextR = config(side: 1, n: n, h: h)

                segsL = (lerpSeg(prevL.0, nextL.0, e), lerpSeg(prevL.1, nextL.1, e))
                segsR = (lerpSeg(prevR.0, nextR.0, e), lerpSeg(prevR.1, nextR.1, e))

                // gentle continuous drift so the lines keep moving on Y
                let dL = sin(t * 0.7 + 3.0) * 4.0
                let dR = sin(t * 0.7 + 7.0) * 4.0
                segsL.0.y += dL
                segsL.1.y += dL
                segsR.0.y += dR
                segsR.1.y += dR

                // keep everything inside the margins
                segsL.0.y = clampY(segsL.0, h: h, margin: margin)
                segsL.1.y = clampY(segsL.1, h: h, margin: margin)
                segsR.0.y = clampY(segsR.0, h: h, margin: margin)
                segsR.1.y = clampY(segsR.1, h: h, margin: margin)
            }
        }

        drawSeg(&ctx, x: leftX, segsL.0, side: -1)
        drawSeg(&ctx, x: leftX, segsL.1, side: -1)
        drawSeg(&ctx, x: rightX, segsR.0, side: 1)
        drawSeg(&ctx, x: rightX, segsR.1, side: 1)
    }

    private func clampY(_ s: Seg, h: Double, margin: Double) -> Double {
        guard s.h > 2 else { return s.y }
        let lo = margin + s.h / 2
        let hi = h - margin - s.h / 2
        return lo > hi ? h / 2 : min(max(s.y, lo), hi)
    }

    private func drawSeg(_ ctx: inout GraphicsContext, x: Double, _ s: Seg, side: Double) {
        guard s.h > 2 else { return }
        let topY = s.y - s.h / 2
        let botY = s.y + s.h / 2

        var spine = Path()
        spine.move(to: CGPoint(x: x, y: topY))
        spine.addLine(to: CGPoint(x: x, y: botY))
        ctx.stroke(spine, with: .color(Palette.accent.opacity(1.0)), lineWidth: 2)

        // short slanted ticks at each end, pointing away from centre
        let tl = 8.0
        var t1 = Path()
        t1.move(to: CGPoint(x: x, y: topY))
        t1.addLine(to: CGPoint(x: x + tl * side, y: topY - tl))
        ctx.stroke(t1, with: .color(Color.white.opacity(0.85)), lineWidth: 1.2)

        var t2 = Path()
        t2.move(to: CGPoint(x: x, y: botY))
        t2.addLine(to: CGPoint(x: x + tl * side, y: botY + tl))
        ctx.stroke(t2, with: .color(Color.white.opacity(0.85)), lineWidth: 1.2)
    }
}
