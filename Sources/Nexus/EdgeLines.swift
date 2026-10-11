// NEXUS Edge Lines — two independent living gutters.
// Left and right share no math: each side owns its own segment count (2–4),
// positions, breath rates, spark clocks. They can never mirror.

import SwiftUI

struct EdgeLinesView: View {
    @ObservedObject private var appState = AppState.shared
    @State private var t0 = Date()

    struct Seg {
        var y: Double
        var h: Double
        var opacity: Double
        var width: Double
        var spark: Double
    }

    /// One fully self-contained side. Seeded from `side` only.
    struct SideModel {
        let side: Double          // -1 left, +1 right
        let seedBase: Double
        let count: Int            // 2…4 segments — can differ per side
        let breathRate: Double    // master tempo — different L vs R
        let sparkEvery: Double
        // per-segment statics
        let fracY: [Double]       // preferred y as fraction of h
        let baseFrac: [Double]    // base height as fraction of h
        let rateMul: [Double]
        let phase: [Double]

        static func rnd(_ seed: Double) -> Double {
            let v = sin(seed * 12.9898 + 78.233) * 43758.5453
            return v - v.rounded(.down)
        }

        init(side: Double) {
            self.side = side
            let sb = side < 0 ? 4.21 : 91.73
            self.seedBase = sb
            let countRnd = Self.rnd(sb + 1)
            self.count = 2 + Int(countRnd * 3)   // 2…4
            self.breathRate = 0.28 + Self.rnd(sb + 2) * 0.35
            self.sparkEvery = 4.5 + Self.rnd(sb + 3) * 5.0
            var ys: [Double] = []
            var bh: [Double] = []
            var rm: [Double] = []
            var ph: [Double] = []
            let n = Double(count)
            for i in 0..<count {
                let fi = Double(i)
                let spread = Self.rnd(sb + 10 + fi) - 0.5
                let rawY = 0.12 + 0.76 * ((fi + 0.5) / n) + spread * 0.22
                let clamped = min(0.9, max(0.1, rawY))
                ys.append(clamped)
                bh.append(0.08 + Self.rnd(sb + 20 + fi) * 0.16)
                rm.append(0.7 + Self.rnd(sb + 30 + fi) * 0.9)
                ph.append(Self.rnd(sb + 40 + fi) * .pi * 2)
            }
            self.fracY = ys
            self.baseFrac = bh
            self.rateMul = rm
            self.phase = ph
        }
    }

    @State private var leftModel = SideModel(side: -1)
    @State private var rightModel = SideModel(side: 1)
    @State private var lastReroll = Date.distantPast

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let w = Double(size.width)
                let h = Double(size.height)
                let t = tl.date.timeIntervalSince(t0)
                let forced = (appState.phase != .running)
                // occasional re-roll of a side's personality (~every 25–40s, staggered)
                if !forced, Date().timeIntervalSince(lastReroll) > 22 {
                    lastReroll = Date()
                    if Int.random(in: 0..<2) == 0 {
                        leftModel = SideModel(side: -1)
                    } else {
                        rightModel = SideModel(side: 1)
                    }
                }
                render(&ctx, w: w, h: h, t: t, forced: forced)
            }
        }
        .allowsHitTesting(false)
    }

    private func easeInOut(_ x: Double) -> Double {
        x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
    }

    private func render(_ ctx: inout GraphicsContext, w: Double, h: Double,
                        t: Double, forced: Bool) {
        let margin = 40.0
        let leftX = 12.0
        let rightX = w - 12.0

        if forced {
            let parked = Seg(y: h / 2, h: h - 2 * margin, opacity: 1, width: 2, spark: -1)
            let empty  = Seg(y: h / 2, h: 0, opacity: 0, width: 2, spark: -1)
            drawSeg(&ctx, x: leftX, parked, side: -1)
            drawSeg(&ctx, x: leftX, empty, side: -1)
            drawSeg(&ctx, x: rightX, parked, side: 1)
            drawSeg(&ctx, x: rightX, empty, side: 1)
            return
        }

        let e = easeInOut(min(1.0, max(0.0, (t - 1.2) / 2.3)))
        renderSide(&ctx, model: leftModel, x: leftX, h: h, t: t, e: e)
        renderSide(&ctx, model: rightModel, x: rightX, h: h, t: t, e: e)
    }

    private func renderSide(_ ctx: inout GraphicsContext, model: SideModel,
                            x: Double, h: Double, t: Double, e: Double) {
        let margin = 40.0
        // one slow independent drift per side
        let sideDrift = sin(t * model.breathRate * 0.6 + model.seedBase) * 14

        for i in 0..<model.count {
            let fi = Double(i)
            let ph = model.phase[i]
            let rm = model.rateMul[i]

            // two layered breaths at incommensurate rates — never repeats cleanly
            let swell = 0.5 + 0.5 * sin(t * model.breathRate * rm + ph)
            let tremor = 0.5 + 0.5 * sin(t * model.breathRate * rm * 2.7 + ph * 1.3 + 1.1)

            let baseH = h * model.baseFrac[i]
            let livingH = baseH * (0.45 + 0.7 * swell) * (0.88 + 0.18 * tremor)

            // parked full line only on the middle-ish segment while emerging
            let parkedH = (i == model.count / 2) ? (h - 2 * margin) * (1 - e) : 0
            let targetY = h * model.fracY[i]
                + sin(t * model.breathRate * rm * 0.8 + ph + fi) * (22 + 8 * fi)
                + sideDrift
            let segY = lerp(h / 2, targetY, e)
            let segH = livingH * e + parkedH

            // heartbeat — unique to this segment
            let beat = 0.5 + 0.5 * sin(t * model.breathRate * rm * 1.6 + ph * 2)
            let op = (0.28 + 0.62 * beat) * e
            let lw = 1.3 + 1.3 * swell * e

            // spark clock is per-side but offset per segment
            let cycle = model.sparkEvery + fi * 1.7
            let sparkSeed = SideModel.rnd(model.seedBase + 50 + fi) * cycle
            let pos = (t + sparkSeed).truncatingRemainder(dividingBy: cycle) / cycle
            let sparkOn = pos < 0.2 && e > 0.85
            let sparkT = sparkOn ? pos / 0.2 : -1

            var s = Seg(y: segY, h: segH, opacity: op, width: lw, spark: sparkT)
            clamp(&s, h: h, margin: margin)
            drawSeg(&ctx, x: x, s, side: model.side)
        }
    }

    private func clamp(_ s: inout Seg, h: Double, margin: Double) {
        guard s.h > 2 else { return }
        let lo = margin + s.h / 2
        let hi = h - margin - s.h / 2
        s.y = lo > hi ? h / 2 : min(max(s.y, lo), hi)
    }

    private func lerp(_ a: Double, _ b: Double, _ p: Double) -> Double {
        a + (b - a) * p
    }

    private func drawSeg(_ ctx: inout GraphicsContext, x: Double, _ s: Seg, side: Double) {
        guard s.h > 2 else { return }
        let topY = s.y - s.h / 2
        let botY = s.y + s.h / 2

        var spine = Path()
        spine.move(to: CGPoint(x: x, y: topY))
        spine.addLine(to: CGPoint(x: x, y: botY))
        ctx.stroke(spine, with: .color(Palette.accent.opacity(s.opacity)), lineWidth: s.width)

        if s.opacity > 0.2 {
            var ghost = Path()
            ghost.move(to: CGPoint(x: x, y: topY + 2))
            ghost.addLine(to: CGPoint(x: x, y: botY - 2))
            ctx.stroke(ghost, with: .color(Palette.accent.opacity(s.opacity * 0.22)),
                       lineWidth: s.width + 3)
        }

        let tl = 6.0 + 4.0 * min(1.0, s.h / 200)
        let tickOp = 0.4 + 0.45 * s.opacity
        var t1 = Path()
        t1.move(to: CGPoint(x: x, y: topY))
        t1.addLine(to: CGPoint(x: x + tl * side, y: topY - tl))
        ctx.stroke(t1, with: .color(Color.white.opacity(tickOp)), lineWidth: 1.2)

        var t2 = Path()
        t2.move(to: CGPoint(x: x, y: botY))
        t2.addLine(to: CGPoint(x: x + tl * side, y: botY + tl))
        ctx.stroke(t2, with: .color(Color.white.opacity(tickOp)), lineWidth: 1.2)

        if s.spark >= 0, s.h > 20 {
            let spY = topY + (botY - topY) * s.spark
            let dash = max(10.0, s.h * 0.08)
            var spark = Path()
            spark.move(to: CGPoint(x: x, y: spY))
            spark.addLine(to: CGPoint(x: x, y: min(botY, spY + dash)))
            let fade = sin(s.spark * .pi)
            ctx.stroke(spark, with: .color(Color.white.opacity(0.9 * fade)), lineWidth: s.width + 0.6)
            ctx.fill(
                Path(ellipseIn: CGRect(x: x - 2.5, y: spY - 2.5, width: 5, height: 5)),
                with: .color(Palette.accent.opacity(0.85 * fade))
            )
        }
    }
}
