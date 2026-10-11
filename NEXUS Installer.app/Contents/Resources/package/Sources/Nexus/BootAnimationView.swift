// NEXUS Boot Sequence v2 — samaritan-grade cold start.
// Phase A: NEXUS mark (red triangle reticle) pulses in at centre.
// Phase B: mark splits into the two edge lines — they elongate as they
//          travel (iconic v1 move), scanline sweeps, data dashes race
//          up the spines, white corner ticks snap in.
// Phase C: lines park (identical geometry to EdgeLinesView handoff).
// Phase D: boot log types out line-by-line with red ✓ seals; radar
//          rings ping outward; faint grid breathes in.
// Phase E: log + rings + grid dissolve, black field lifts, parked
//          lines remain → world revealed.
// Plays forward on launch, reversed on close (pure function of p).

import SwiftUI

struct BootAnimationView: View {
    var reversed: Bool = false
    var duration: Double = 2.6
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

    // MARK: - Easing / helpers

    private func easeOutCubic(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
    private func easeOutQuint(_ x: Double) -> Double { 1 - pow(1 - x, 5) }
    private func easeInOut(_ x: Double) -> Double {
        x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
    }
    private func clamp01(_ x: Double) -> Double { min(1.0, max(0.0, x)) }
    /// sub-progress of [a,b] window
    private func seg(_ p: Double, _ a: Double, _ b: Double) -> Double {
        clamp01((p - a) / (b - a))
    }
    /// deterministic pseudo-random 0..1 from an integer seed
    private func hash(_ n: Int) -> Double {
        let x = sin(Double(n) * 127.1 + 311.7) * 43758.5453
        return x - floor(x)
    }

    // MARK: - Draw

    private func draw(ctx: inout GraphicsContext, size: CGSize, p: Double) {
        let w = Double(size.width), h = Double(size.height)
        let cx = w / 2, cy = h / 2
        let edgeX: Double = 12.0
        let span = cx - edgeX
        let margin: Double = 40.0
        let targetH = h - 2 * margin

        // ── black field: full until the reveal window ──
        let blackA = 1.0 - seg(p, 0.80, 0.96)
        if blackA > 0.001 {
            var field = Path()
            field.addRect(CGRect(x: 0, y: 0, width: w, height: h))
            ctx.fill(field, with: .color(Color.black.opacity(blackA)))
        }

        // ── Phase A: mark pulses in (0.00–0.14), holds through split ──
        let markIn = seg(p, 0.00, 0.10)
        let markOut = 1.0 - seg(p, 0.14, 0.22)
        let markA = markIn * markOut
        if markA > 0.01 {
            drawMark(ctx: &ctx, cx: cx, cy: cy,
                     scale: 0.6 + 0.4 * easeOutQuint(markIn),
                     alpha: markA, p: p)
        }

        // ── Phase B: lines split + travel + elongate (0.14–0.45) ──
        let travelP = seg(p, 0.14, 0.45)
        let h0 = targetH * easeOutCubic(travelP)
        let lineA = seg(p, 0.12, 0.20)

        for side in [-1.0, 1.0] {
            let x = cx + side * span * easeInOut(travelP)
            drawBigLine(ctx: &ctx, x: x, height: h0, dir: side,
                        centerY: cy, alpha: lineA, p: p, side: side)
        }

        // ── scanline sweep while they travel ──
        let scanP = seg(p, 0.16, 0.50)
        if scanP > 0.01 && scanP < 0.99 {
            let y = h * (1.1 - 1.2 * scanP)
            var scan = Path()
            scan.move(to: CGPoint(x: 0, y: y))
            scan.addLine(to: CGPoint(x: w, y: y))
            let fade = sin(scanP * .pi)
            ctx.stroke(scan, with: .color(.white.opacity(0.10 * fade)), lineWidth: 1)
            var glow = Path()
            glow.addRect(CGRect(x: 0, y: y - 18, width: w, height: 36))
            ctx.fill(glow, with: .linearGradient(
                Gradient(colors: [Palette.accent.opacity(0), Palette.accent.opacity(0.06 * fade), Palette.accent.opacity(0)]),
                startPoint: CGPoint(x: 0, y: y - 18), endPoint: CGPoint(x: 0, y: y + 18)))
        }

        // ── centre dot while the lines are still leaving ──
        let dotAlpha = max(0.0, markA - travelP * 1.4)
        if dotAlpha > 0.01 {
            ctx.fill(
                Path(ellipseIn: CGRect(x: cx - 3, y: cy - 3, width: 6, height: 6)),
                with: .color(Color.white.opacity(dotAlpha))
            )
        }

        // ── Phase D: grid breathes in, radar pings, log types (0.48–0.90) ──
        let gridA = seg(p, 0.48, 0.62) * (1.0 - seg(p, 0.82, 0.94))
        if gridA > 0.01 { drawGrid(ctx: &ctx, size: size, alpha: gridA) }

        let pingA = (1.0 - seg(p, 0.55, 0.85))
        if pingA > 0.01 { drawPings(ctx: &ctx, cx: cx, cy: cy, r: min(w, h) * 0.45, p: p, alpha: pingA) }

        let logA = (1.0 - seg(p, 0.80, 0.92))
        if logA > 0.01 { drawLog(ctx: &ctx, cx: cx, cy: cy, p: p, alpha: logA) }
    }

    // MARK: - NEXUS mark (triangle reticle)

    private func drawMark(ctx: inout GraphicsContext, cx: Double, cy: Double,
                          scale: Double, alpha: Double, p: Double) {
        let s = 16.0 * scale
        // triangle outline
        var tri = Path()
        tri.move(to: CGPoint(x: cx, y: cy - s))
        tri.addLine(to: CGPoint(x: cx + s * 0.92, y: cy + s * 0.72))
        tri.addLine(to: CGPoint(x: cx - s * 0.92, y: cy + s * 0.72))
        tri.closeSubpath()
        ctx.stroke(tri, with: .color(Palette.accent.opacity(alpha)), lineWidth: 1.6)

        // inner dot
        ctx.fill(Path(ellipseIn: CGRect(x: cx - 1.8, y: cy - 1.8, width: 3.6, height: 3.6)),
                 with: .color(Color.white.opacity(alpha)))

        // reticle brackets — two arcs that close in with the pulse
        let bracketP = easeOutQuint(seg(p, 0.0, 0.10))
        let r = s + 8 + (1 - bracketP) * 22
        for k in 0..<4 {
            let a0 = Double(k) * .pi / 2 + .pi / 4
            let gap = 0.22 + (1 - bracketP) * 0.30
            var arc = Path()
            arc.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                       startAngle: .radians(a0 + gap), endAngle: .radians(a0 + .pi / 2 - gap),
                       clockwise: false)
            ctx.stroke(arc, with: .color(Color.white.opacity(alpha * 0.55)), lineWidth: 1)
        }
    }

    // MARK: - Big parked line (v1 geometry + data dashes)

    private func drawBigLine(ctx: inout GraphicsContext, x: Double, height: Double,
                             dir: Double, centerY: Double, alpha: Double,
                             p: Double, side: Double) {
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

        // data dashes racing along the spine while travelling, then a
        // slow ambient drift once parked
        guard height > 40 else { return }
        let dashA = alpha * (0.75 * seg(p, 0.18, 0.30))
        if dashA > 0.01 {
            let seed = side > 0 ? 7 : 19
            for i in 0..<7 {
                let speed = 0.35 + hash(seed + i) * 0.5
                let phase = (p * speed * 3.0 + hash(seed + i * 3)) .truncatingRemainder(dividingBy: 1.0)
                let y = botY - phase * height
                let len = 8 + hash(seed + i * 7) * 22
                var dash = Path()
                dash.move(to: CGPoint(x: x, y: y))
                dash.addLine(to: CGPoint(x: x, y: y - len))
                let tipA = dashA * (0.4 + 0.6 * hash(seed + i * 11))
                ctx.stroke(dash, with: .color(Color.white.opacity(tipA)), lineWidth: 1)
            }
        }
    }

    // MARK: - Grid

    private func drawGrid(ctx: inout GraphicsContext, size: CGSize, alpha: Double) {
        let step: Double = 44
        let w = Double(size.width), h = Double(size.height)
        let col = Palette.accent.opacity(alpha * 0.10)
        var grid = Path()
        var x = step / 2
        while x < w { grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: h)); x += step }
        var y = step / 2
        while y < h { grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: w, y: y)); y += step }
        ctx.stroke(grid, with: .color(col), lineWidth: 0.5)
    }

    // MARK: - Radar pings

    private func drawPings(ctx: inout GraphicsContext, cx: Double, cy: Double,
                           r: Double, p: Double, alpha: Double) {
        for i in 0..<3 {
            let local = seg(p, 0.50 + Double(i) * 0.08, 0.80 + Double(i) * 0.08)
            if local <= 0.01 || local >= 0.99 { continue }
            let rad = r * easeOutCubic(local)
            let a = alpha * (1.0 - local) * 0.5
            var ring = Path()
            ring.addEllipse(in: CGRect(x: cx - rad, y: cy - rad, width: rad * 2, height: rad * 2))
            ctx.stroke(ring, with: .color(Palette.accent.opacity(a)), lineWidth: 1)
        }
    }

    // MARK: - Boot log

    private struct LogLine { let label: String; let status: String; let ok: Bool }

    private func drawLog(ctx: inout GraphicsContext, cx: Double, cy: Double,
                         p: Double, alpha: Double) {
        let lines = [
            LogLine(label: "NEURAL LINK",      status: "LOCKED",   ok: true),
            LogLine(label: "OLLAMA CORE",      status: "ONLINE",   ok: true),
            LogLine(label: "MEMORY LATTICE",   status: "SEALED",   ok: true),
            LogLine(label: "PERMISSION GATE",  status: "ARMED",    ok: true),
            LogLine(label: "NEXUS",            status: "READY",    ok: true),
        ]
        let font = Font.system(size: 10, weight: .medium, design: .monospaced)
        let rowH: Double = 16
        let startY = cy + 44

        for (i, line) in lines.enumerated() {
            // line i starts typing at 0.52 + i*0.045, done 0.05 later
            let t = seg(p, 0.52 + Double(i) * 0.045, 0.58 + Double(i) * 0.045)
            if t <= 0.01 { continue }
            let y = startY + Double(i) * rowH
            let full = " \(line.label) ····· \(line.status)"
            let chars = Int(ceil(Double(full.count) * easeOutCubic(t)))
            let shown = String(full.prefix(chars))
            let isDone = t >= 0.99

            let text = Text(shown)
                .font(font)
                .foregroundColor(isDone ? Color.white.opacity(alpha * 0.85)
                                        : Palette.accent.opacity(alpha))
            ctx.draw(text, at: CGPoint(x: cx, y: y), anchor: .center)

            if isDone {
                let tick = Text("✓").font(font).foregroundColor(Palette.accent.opacity(alpha))
                let halfW = Double(full.count) * 6.0 / 2.0 + 10
                ctx.draw(tick, at: CGPoint(x: cx + halfW, y: y), anchor: .center)
            }
        }
    }
}
