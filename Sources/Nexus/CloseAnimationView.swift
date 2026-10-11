// NEXUS Close Sequence — sever-the-link shutdown.
// 0.0–0.10: grid snaps in with a hard flicker; "SEVERING LINK" header blinks.
// 0.08–0.40: log un-seals top-to-bottom, each line flips to a red ✕ and dies.
// 0.15–0.55: radar rings collapse inward (converging, not pinging out).
// 0.35–0.72: parked lines retract — height dies, X travels back to centre,
//            corner ticks flip inward; reverse scanline sweeps down.
// 0.72–0.86: lines merge into the triangle mark; mark shrinks; white flash.
// 0.86–1.00: CRT power-off collapse to a single line, then black.
// Pure function of p — plays once forward on close.

import SwiftUI

struct CloseAnimationView: View {
    var duration: Double = 1.8
    var onDone: () -> Void = {}

    @State private var start = Date()
    @State private var fired = false

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let elapsed = timeline.date.timeIntervalSince(start)
                let p = min(1.0, max(0.0, elapsed / duration))
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

    private func easeInCubic(_ x: Double) -> Double { x * x * x }
    private func easeOutCubic(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
    private func easeInOut(_ x: Double) -> Double {
        x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
    }
    private func clamp01(_ x: Double) -> Double { min(1.0, max(0.0, x)) }
    private func seg(_ p: Double, _ a: Double, _ b: Double) -> Double {
        clamp01((p - a) / (b - a))
    }
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

        // ── opaque black field for the whole shutdown ──
        var field = Path()
        field.addRect(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.fill(field, with: .color(.black))

        // ── grid: snaps in hard, flickers, dies ──
        let gridIn = seg(p, 0.00, 0.06)
        let gridOut = 1.0 - seg(p, 0.62, 0.78)
        var gridA = gridIn * gridOut
        if gridA > 0.01 {
            // hard flicker driven by quantised time
            let flick = hash(Int(p * 28.0))
            gridA *= 0.55 + 0.45 * flick
            drawGrid(ctx: &ctx, size: size, alpha: gridA)
        }

        // ── SEVERING LINK header ──
        let headA = seg(p, 0.02, 0.08) * (1.0 - seg(p, 0.40, 0.50))
        if headA > 0.01 {
            let blink = (Int(p * 14.0) % 2 == 0) ? 1.0 : 0.35
            let head = Text("◤ SEVERING NEURAL LINK")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Palette.accent.opacity(headA * blink))
            ctx.draw(head, at: CGPoint(x: cx, y: cy - targetH / 2 - 26), anchor: .center)
        }

        // ── rings converge inward ──
        let ringA = seg(p, 0.10, 0.16) * (1.0 - seg(p, 0.45, 0.58))
        if ringA > 0.01 {
            for i in 0..<3 {
                let local = seg(p, 0.12 + Double(i) * 0.06, 0.50 + Double(i) * 0.06)
                if local <= 0.01 { continue }
                let maxR = min(w, h) * 0.48
                let rad = maxR * (1.0 - easeInCubic(local))
                if rad < 4 { continue }
                var ring = Path()
                ring.addEllipse(in: CGRect(x: cx - rad, y: cy - rad, width: rad * 2, height: rad * 2))
                ctx.stroke(ring, with: .color(Palette.accent.opacity(ringA * (1.0 - local) * 0.55)), lineWidth: 1)
            }
        }

        // ── log un-seals: each line flips to ✕ then dies ──
        let logA = 1.0 - seg(p, 0.48, 0.58)
        if logA > 0.01 { drawLogCollapse(ctx: &ctx, cx: cx, cy: cy, p: p, alpha: logA) }

        // ── reverse scanline sweeping down ──
        let scanP = seg(p, 0.30, 0.62)
        if scanP > 0.01 && scanP < 0.99 {
            let y = h * (-0.1 + 1.2 * scanP)
            var scan = Path()
            scan.move(to: CGPoint(x: 0, y: y))
            scan.addLine(to: CGPoint(x: w, y: y))
            let fade = sin(scanP * .pi)
            ctx.stroke(scan, with: .color(.white.opacity(0.10 * fade)), lineWidth: 1)
        }

        // ── lines retract to centre, then merge into the mark ──
        let retractP = easeInCubic(seg(p, 0.35, 0.72))
        let hNow = targetH * (1.0 - retractP)
        let lineA = seg(p, 0.00, 0.04) * (1.0 - seg(p, 0.70, 0.80))
        if lineA > 0.01 && hNow > 2 {
            for side in [-1.0, 1.0] {
                let x = cx + side * span * (1.0 - easeInOut(retractP))
                drawRetractingLine(ctx: &ctx, x: x, height: hNow, dir: side,
                                   centerY: cy, alpha: lineA, retractP: retractP)
            }
        }

        // ── merge flash + dying mark ──
        let markP = seg(p, 0.72, 0.86)
        if markP > 0.01 {
            let s = 16.0 * (1.0 - easeInCubic(markP))
            let markA = (1.0 - seg(p, 0.80, 0.88))
            if s > 0.5 && markA > 0.01 {
                var tri = Path()
                tri.move(to: CGPoint(x: cx, y: cy - s))
                tri.addLine(to: CGPoint(x: cx + s * 0.92, y: cy + s * 0.72))
                tri.addLine(to: CGPoint(x: cx - s * 0.92, y: cy + s * 0.72))
                tri.closeSubpath()
                ctx.stroke(tri, with: .color(Palette.accent.opacity(markA)), lineWidth: 1.6)
            }
        }
        let flashA = seg(p, 0.76, 0.80) * (1.0 - seg(p, 0.80, 0.87))
        if flashA > 0.01 {
            let r = 3 + 26 * seg(p, 0.76, 0.83)
            ctx.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                     with: .color(.white.opacity(flashA * 0.9)))
        }

        // ── CRT power-off: everything collapses to one line, then gone ──
        let crtP = seg(p, 0.86, 0.97)
        if crtP > 0.01 {
            let lineH = max(1.0, 26 * (1.0 - easeInCubic(crtP)))
            let lineW = w * (1.0 - 0.15 * crtP)
            let a = (1.0 - seg(p, 0.93, 1.0))
            var bar = Path()
            bar.addRect(CGRect(x: (w - lineW) / 2, y: cy - lineH / 2, width: lineW, height: lineH))
            ctx.fill(bar, with: .color(.white.opacity(0.85 * a)))
            var glow = Path()
            glow.addRect(CGRect(x: (w - lineW) / 2, y: cy - lineH * 2, width: lineW, height: lineH * 4))
            ctx.fill(glow, with: .color(.white.opacity(0.12 * a)))
        }
    }

    // MARK: - Grid

    private func drawGrid(ctx: inout GraphicsContext, size: CGSize, alpha: Double) {
        let step: Double = 44
        let w = Double(size.width), h = Double(size.height)
        var grid = Path()
        var x = step / 2
        while x < w { grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: h)); x += step }
        var y = step / 2
        while y < h { grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: w, y: y)); y += step }
        ctx.stroke(grid, with: .color(Palette.accent.opacity(alpha * 0.10)), lineWidth: 0.5)
    }

    // MARK: - Retracting line (v1 geometry, ticks flip inward near the end)

    private func drawRetractingLine(ctx: inout GraphicsContext, x: Double, height: Double,
                                    dir: Double, centerY: Double, alpha: Double,
                                    retractP: Double) {
        let topY = centerY - height / 2
        let botY = centerY + height / 2

        var spine = Path()
        spine.move(to: CGPoint(x: x, y: topY))
        spine.addLine(to: CGPoint(x: x, y: botY))
        ctx.stroke(spine, with: .color(Palette.accent.opacity(alpha)), lineWidth: 2)

        // ticks point away early, flip inward as the line collapses
        let flip = retractP > 0.75 ? -1.0 : 1.0
        let tl = 12.0 * (1.0 - 0.6 * retractP)
        var t1 = Path()
        t1.move(to: CGPoint(x: x, y: topY))
        t1.addLine(to: CGPoint(x: x + tl * dir * flip, y: topY + tl * (retractP > 0.75 ? 1 : -1)))
        ctx.stroke(t1, with: .color(Color.white.opacity(alpha * 0.9)), lineWidth: 1.4)
        var t2 = Path()
        t2.move(to: CGPoint(x: x, y: botY))
        t2.addLine(to: CGPoint(x: x + tl * dir * flip, y: botY + tl * (retractP > 0.75 ? -1 : 1)))
        ctx.stroke(t2, with: .color(Color.white.opacity(alpha * 0.9)), lineWidth: 1.4)
    }

    // MARK: - Log collapse

    private struct LogLine { let label: String }

    private func drawLogCollapse(ctx: inout GraphicsContext, cx: Double, cy: Double,
                                 p: Double, alpha: Double) {
        let lines = [
            LogLine(label: "NEURAL LINK"),
            LogLine(label: "OLLAMA CORE"),
            LogLine(label: "MEMORY LATTICE"),
            LogLine(label: "PERMISSION GATE"),
            LogLine(label: "NEXUS"),
        ]
        let font = Font.system(size: 10, weight: .medium, design: .monospaced)
        let rowH: Double = 16
        let startY = cy + 44

        for (i, line) in lines.enumerated() {
            // each line starts collapsing at 0.10 + i*0.05
            let t = seg(p, 0.10 + Double(i) * 0.05, 0.30 + Double(i) * 0.05)
            if t >= 0.99 { continue }
            let y = startY + Double(i) * rowH
            let full = " \(line.label) ····· SEALED"
            let dead = " \(line.label) ····· ✕✕✕✕✕"

            if t <= 0.01 {
                // still sealed
                let text = Text(full).font(font).foregroundColor(Color.white.opacity(alpha * 0.85))
                ctx.draw(text, at: CGPoint(x: cx, y: y), anchor: .center)
            } else {
                // flipping char-by-char to the dead version, then fading
                let chars = Int(ceil(Double(full.count) * easeOutCubic(t)))
                var mixed = Array(full)
                let deadArr = Array(dead)
                for j in 0..<min(chars, mixed.count) { mixed[j] = deadArr[j] }
                let fade = 1.0 - t
                let text = Text(String(mixed))
                    .font(font)
                    .foregroundColor(Palette.accent.opacity(alpha * fade))
                ctx.draw(text, at: CGPoint(x: cx, y: y), anchor: .center)
            }
        }
    }
}
