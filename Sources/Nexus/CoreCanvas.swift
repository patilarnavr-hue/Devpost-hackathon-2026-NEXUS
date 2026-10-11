// NEXUS Core Observatory — the visual identity.
// A geometric intelligence core whose environment reorganizes itself by state:
// rings accelerate when thinking, sources constellate when researching,
// routes form toward tools when executing, trajectories fracture and regrow
// on failure/replan, and a verification seal locks in on success.

import SwiftUI

// MARK: - Data driven from real engine state

struct SourceNode: Identifiable {
    let id = UUID()
    let label: String
    let kind: String
    let firstSeen: Date
}

struct CoreCanvas: View {
    @EnvironmentObject var engine: NexusEngine

    @State private var stateEnteredAt = Date()
    @State private var sealEnteredAt: Date?
    @State private var fractureEnteredAt: Date?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { ctx, size in
                draw(ctx: &ctx, size: size, now: timeline.date)
            }
        }
        .onAppear {
            stateEnteredAt = Date()
            if engine.verification == .passed { sealEnteredAt = Date() }
            if engine.verification == .failed || engine.state == .error { fractureEnteredAt = Date() }
        }
        .onChange(of: engine.state) { newState in
            stateEnteredAt = Date()
            if newState == .error { fractureEnteredAt = Date() }
            if newState == .success, engine.verification == .passed { sealEnteredAt = Date() }
        }
        .onChange(of: engine.verification) { v in
            switch v {
            case .passed:
                sealEnteredAt = Date()
                fractureEnteredAt = nil
            case .failed:
                fractureEnteredAt = Date()
            default:
                break
            }
        }
    }

    // MARK: - Derived real data

    private var sourceNodes: [SourceNode] {
        // Real arbitration payload: sources actually consulted this run.
        if let arb = engine.arbitration, !arb.sources.isEmpty {
            var nodes: [SourceNode] = []
            var seen = Set<String>()
            for s in arb.sources {
                let style = CoreCanvas.nodeStyle(for: s.tool)
                if seen.insert(style.label).inserted {
                    nodes.append(SourceNode(label: style.label, kind: style.kind,
                                            firstSeen: engine.arbitrationAt))
                    if nodes.count >= 7 { break }
                }
            }
            return nodes
        }
        // Fallback: derive nodes from event messages (pre-arbitration activity).
        var nodes: [SourceNode] = []
        var seen = Set<String>()
        for e in engine.events {
            let m = e.message.lowercased()
            var label: String?
            var kind = "web"
            if m.contains("web.search") || m.contains("search web") { label = "WEB"; kind = "web" }
            else if m.contains("github") { label = "GITHUB"; kind = "github" }
            else if m.contains("extract") { label = "DOCS"; kind = "doc" }
            else if m.contains("memory") { label = "MEMORY"; kind = "memory" }
            else if m.contains("calendar") { label = "CALENDAR"; kind = "calendar" }
            else if m.contains("diagram") { label = "DIAGRAM"; kind = "diagram" }
            else if m.contains("files") || m.contains("workspace") { label = "FILES"; kind = "file" }
            if let l = label, seen.insert(l).inserted {
                nodes.append(SourceNode(label: l, kind: kind, firstSeen: e.timestamp))
                if nodes.count >= 7 { break }
            }
        }
        return nodes
    }

    private static func nodeStyle(for tool: String) -> (label: String, kind: String) {
        if tool.contains("github") { return ("GITHUB", "github") }
        if tool.contains("web.extract") || tool.contains("extract") { return ("DOCS", "doc") }
        if tool.contains("web") { return ("WEB", "web") }
        if tool.contains("memory") { return ("MEMORY", "memory") }
        if tool.contains("calendar") { return ("CALENDAR", "calendar") }
        if tool.contains("diagram") { return ("DIAGRAM", "diagram") }
        if tool.contains("files") { return ("FILES", "file") }
        let upper = tool.uppercased()
        return (upper.count > 9 ? String(upper.prefix(9)) : upper, "file")
    }

    private var activeTools: [String] {
        var tools: [String] = []
        if !engine.activeTool.isEmpty && engine.activeTool != "—" {
            tools.append(engine.activeTool)
        }
        for step in engine.plan?.steps ?? [] where !step.tool.isEmpty {
            if !tools.contains(step.tool) { tools.append(step.tool) }
        }
        return Array(tools.prefix(5))
    }

    private var steps: [PlanStepData] { engine.plan?.steps ?? [] }

    // MARK: - Geometry helpers

    private func hash(_ n: Double) -> Double {
        let x = sin(n * 127.1) * 43758.5453
        return x - x.rounded(.down)
    }

    private func ellipseRing(cx: Double, cy: Double, rx: Double, ry: Double, rot: Double) -> Path {
        var p = Path()
        var first = true
        for a in stride(from: 0.0, through: .pi * 2, by: 0.10) {
            let lx = rx * cos(a), ly = ry * sin(a)
            let x = cx + lx * cos(rot) - ly * sin(rot)
            let y = cy + lx * sin(rot) + ly * cos(rot)
            if first { p.move(to: CGPoint(x: x, y: y)); first = false }
            else { p.addLine(to: CGPoint(x: x, y: y)) }
        }
        p.closeSubpath()
        return p
    }

    private func circlePath(_ c: CGPoint, _ r: Double) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    // MARK: - The draw pass

    private func draw(ctx: inout GraphicsContext, size: CGSize, now: Date) {
        let t = now.timeIntervalSinceReferenceDate
        let w = Double(size.width), h = Double(size.height)
        let cx = w / 2, cy = h * 0.46
        let center = CGPoint(x: cx, y: cy)
        let minDim = min(w, h)

        let st = engine.state

        // Activity drives everything: 0 idle … 1 critical
        let activity: Double
        switch st {
        case .idle: activity = 0.06
        case .perceiving, .analyzing: activity = 0.45
        case .planning, .replanning: activity = 0.5
        case .waitingForPermission: activity = 0.5
        case .executing: activity = 0.75
        case .verifying: activity = 0.65
        case .success: activity = 0.3
        case .error: activity = 1.0
        }

        let pulse = 0.7 + 0.3 * sin(t * 3.2)
        let errorFlash = st == .error ? 0.55 + 0.45 * sin(t * 6.0) : 1.0

        // ── Ambient particles (99% disappear when nothing is happening) ──
        for i in 0..<56 {
            let f = Double(i)
            let baseA = hash(f + 1) * .pi * 2
            let spd = (hash(f + 7) - 0.5) * 0.10
            let r0 = minDim * (0.14 + hash(f + 13) * 0.42)
            let ang = baseA + t * spd
            let rr = r0 + sin(t * 0.35 + f) * 9
            let px = cx + cos(ang) * rr
            let py = cy + sin(ang) * rr * 0.82
            let sz = 1.0 + hash(f + 21) * 1.6
            let op = (0.035 + activity * 0.11) * (0.5 + hash(f + 3) * 0.5)
            ctx.fill(
                Path(ellipseIn: CGRect(x: px - sz / 2, y: py - sz / 2, width: sz, height: sz)),
                with: .color(Color.white.opacity(op))
            )
        }

        // ── Orbital rings — geometry accelerates with thought ──
        let expansion: Double
        switch st {
        case .perceiving, .analyzing: expansion = 16
        case .planning: expansion = 8
        case .executing: expansion = 10
        case .replanning: expansion = -4
        case .error: expansion = -10
        default: expansion = 0
        }
        let speedScale = st == .idle ? 0.25 : (st == .error ? 2.2 : 1.0)

        for i in 0..<4 {
            let rx = minDim * (0.10 + 0.048 * Double(i)) + expansion * (Double(i) + 1) / 4
            let ry = rx * 0.40
            let rot = t * (0.10 + Double(i) * 0.14) * speedScale
            let isPrimary = (i == 2)
            let color: Color = isPrimary
                ? Palette.accent.opacity((0.35 + activity * 0.45) * (st == .error ? errorFlash : 1))
                : Color.white.opacity(0.10 + activity * 0.18)
            ctx.stroke(
                ellipseRing(cx: cx, cy: cy, rx: rx, ry: ry, rot: rot),
                with: .color(color),
                lineWidth: isPrimary ? 1.3 : 0.8
            )
        }

        // ── Nucleus ──
        let nucleusColor: Color
        switch st {
        case .idle: nucleusColor = Color.white.opacity(0.85)
        case .success: nucleusColor = Palette.seal
        case .error: nucleusColor = Palette.critical.opacity(errorFlash)
        default: nucleusColor = Palette.accent
        }
        let nucR = 5.0 + sin(t * 1.6) * (st == .idle ? 0.3 : 0.9)
        for (g, o) in [(11.0, 0.05), (6.5, 0.10), (3.0, 0.16)] {
            ctx.fill(circlePath(center, nucR + g * (0.6 + activity * 0.6)),
                     with: .color(nucleusColor.opacity(o * (0.5 + activity))))
        }
        ctx.fill(circlePath(center, nucR), with: .color(nucleusColor))

        // ── GOAL node — the task forms the interface ──
        let objective = engine.objective
        if !objective.isEmpty {
            let goalY = 34.0
            let text = objective.count > 46 ? String(objective.prefix(44)) + "…" : objective
            let boxW = min(w * 0.62, Double(text.count) * 6.6 + 56)
            let box = CGRect(x: cx - boxW / 2, y: goalY - 15, width: boxW, height: 34)
            var boxPath = Path(roundedRect: box, cornerRadius: 4)
            ctx.stroke(boxPath, with: .color(Color.white.opacity(0.35)), lineWidth: 1)
            ctx.draw(Text("GOAL").font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(Palette.accent),
                     at: CGPoint(x: cx - boxW / 2 + 24, y: goalY - 7))
            ctx.draw(Text(text).font(.system(size: 11, design: .monospaced)).foregroundColor(.white),
                     at: CGPoint(x: cx + 10, y: goalY + 6))
            // connector with travelling pulse
            let lineTop = goalY + 22
            let ringOuter = minDim * 0.29 + expansion * 0.4
            let lineBottom = cy - ringOuter
            if lineBottom > lineTop {
                var conn = Path()
                conn.move(to: CGPoint(x: cx, y: lineTop))
                conn.addLine(to: CGPoint(x: cx, y: lineBottom))
                ctx.stroke(conn, with: .color(Color.white.opacity(0.22)), lineWidth: 1)
                let frac = (t * 0.45).truncatingRemainder(dividingBy: 1.0)
                let dotY = lineTop + (lineBottom - lineTop) * frac
                ctx.fill(circlePath(CGPoint(x: cx, y: dotY), 2.2),
                         with: .color(Palette.accent.opacity(0.9)))
            }
        }

        // ── Source constellation (upper arc) — where information came from ──
        let sources = sourceNodes
        if !sources.isEmpty {
            let researching = engine.workflowName == "research"
            let radius = minDim * 0.38 + (researching ? 18 : 0)
            let spanStart = .pi * 1.10   // upper arc
            let spanEnd = .pi * 1.90
            for (i, src) in sources.enumerated() {
                let frac = sources.count == 1 ? 0.5 : Double(i) / Double(sources.count - 1)
                let ang = spanStart + (spanEnd - spanStart) * frac
                let p = CGPoint(x: cx + cos(ang) * radius, y: cy + sin(ang) * radius * 0.86)

                let age = now.timeIntervalSince(src.firstSeen)
                let fresh = age < 6.0 ? (1.0 - age / 6.0) : 0.0

                // relationship line — brightens when the source just arrived
                var conn = Path()
                conn.move(to: center)
                conn.addLine(to: p)
                ctx.stroke(conn, with: .color(Palette.accent.opacity(0.12 + fresh * 0.7)),
                           lineWidth: 0.8 + fresh)

                // shape encodes source type
                switch src.kind {
                case "github":
                    var ghP = Path()
                    ghP.addRect(CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8))
                    ctx.fill(ghP, with: .color(Palette.accent.opacity(0.5 + fresh * 0.5)))
                case "doc":
                    var docP = Path()
                    docP.addRect(CGRect(x: p.x - 4, y: p.y - 5.5, width: 8, height: 11))
                    docP.move(to: CGPoint(x: p.x + 1, y: p.y - 5.5))
                    docP.addLine(to: CGPoint(x: p.x + 4, y: p.y - 2.5))
                    docP.addLine(to: CGPoint(x: p.x + 1, y: p.y - 2.5))
                    ctx.stroke(docP, with: .color(Palette.accent.opacity(0.55 + fresh * 0.45)), lineWidth: 1.2)
                case "file":
                    var fp = Path(roundedRect: CGRect(x: p.x - 5, y: p.y - 3.5, width: 10, height: 7.5),
                                  cornerRadius: 1.5)
                    ctx.stroke(fp, with: .color(Palette.accent.opacity(0.5 + fresh * 0.5)), lineWidth: 1.2)
                case "memory", "calendar":
                    ctx.stroke(circlePath(p, 4.5),
                               with: .color(Palette.accent.opacity(0.5 + fresh * 0.5)), lineWidth: 1.2)
                case "diagram":
                    var tri = Path()
                    tri.move(to: CGPoint(x: p.x, y: p.y - 5))
                    tri.addLine(to: CGPoint(x: p.x + 5, y: p.y + 4))
                    tri.addLine(to: CGPoint(x: p.x - 5, y: p.y + 4))
                    tri.closeSubpath()
                    ctx.stroke(tri, with: .color(Palette.accent.opacity(0.5 + fresh * 0.5)), lineWidth: 1.2)
                default: // web
                    ctx.fill(circlePath(p, 3.6),
                             with: .color(Palette.accent.opacity(0.55 + fresh * 0.45)))
                }

                // identifier — WEB-01, GITHUB-02 …
                let tag = "\(src.label)-\(String(format: "%02d", i + 1))"
                ctx.draw(Text(tag).font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.5 + fresh * 0.5)),
                         at: CGPoint(x: p.x, y: p.y + 14))
            }
        }

        // ── Tool orbits (lower arc) — tools move into the field when needed ──
        let tools = activeTools
        var toolPositions: [String: CGPoint] = [:]
        if !tools.isEmpty {
            let radius = minDim * 0.33
            let start = .pi * 0.14
            let end = .pi * 0.86
            for (i, tool) in tools.enumerated() {
                let frac = tools.count == 1 ? 0.5 : Double(i) / Double(tools.count - 1)
                let ang = start + (end - start) * frac
                let p = CGPoint(x: cx + cos(ang) * radius, y: cy + sin(ang) * radius)
                toolPositions[tool] = p

                let isActive = tool == engine.activeTool && (st == .executing || st == .verifying)
                let nodeColor = isActive ? Palette.accent : Palette.accent.opacity(0.30)

                if isActive {
                    for g in [6.0, 10.0] {
                        ctx.stroke(circlePath(p, g), with: .color(Palette.accent.opacity(0.20 * pulse)),
                                   lineWidth: 1)
                    }
                }
                ctx.fill(Path(roundedRect: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8),
                              cornerRadius: 1.5),
                         with: .color(nodeColor))

                let short = tool.replacingOccurrences(of: "web.", with: "")
                    .replacingOccurrences(of: "github.", with: "")
                    .replacingOccurrences(of: "files.", with: "")
                ctx.draw(Text(short.uppercased()).font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(isActive ? .white : Color.white.opacity(0.45)),
                         at: CGPoint(x: p.x, y: p.y + 14))
            }
        }

        // ── Route — a path forms from core toward the active tool ──
        if st == .executing, let activePos = toolPositions[engine.activeTool] {
            var route = Path()
            route.move(to: CGPoint(x: cx, y: cy))
            route.addLine(to: activePos)
            ctx.stroke(route,
                       with: .color(Palette.accent.opacity(0.85)),
                       style: StrokeStyle(lineWidth: 1.5, dash: [6, 6],
                                          dashPhase: CGFloat(-t * 26) * 1.0))
            // travelling packet
            let frac = (t * 0.9).truncatingRemainder(dividingBy: 1.0)
            let px = cx + (activePos.x - cx) * frac
            let py = cy + (activePos.y - cy) * frac
            ctx.fill(circlePath(CGPoint(x: px, y: py), 2.6), with: .color(Palette.accent))
        }

        // ── Fracture — the false-success moment ──
        if fractureEnteredAt != nil && st != .success {
            let r = minDim * 0.30
            let gapCenter = -Double.pi / 2 + 0.6
            var ring = Path()
            ring.addArc(center: center, radius: r,
                        startAngle: .radians(gapCenter + 0.16),
                        endAngle: .radians(gapCenter + .pi * 2 - 0.16),
                        clockwise: false)
            ctx.stroke(ring, with: .color(Palette.critical.opacity(0.55 * errorFlash)), lineWidth: 1.4)

            // the break
            let gx = cx + cos(gapCenter) * r
            let gy = cy + sin(gapCenter) * r
            let s: Double = 5
            var x1 = Path()
            x1.move(to: CGPoint(x: gx - s, y: gy - s))
            x1.addLine(to: CGPoint(x: gx + s, y: gy + s))
            var x2 = Path()
            x2.move(to: CGPoint(x: gx + s, y: gy - s))
            x2.addLine(to: CGPoint(x: gx - s, y: gy + s))
            ctx.stroke(x1, with: .color(Palette.critical.opacity(errorFlash)), lineWidth: 2)
            ctx.stroke(x2, with: .color(Palette.critical.opacity(errorFlash)), lineWidth: 2)

            ctx.draw(Text("VERIFICATION FAILED").font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Palette.critical.opacity(errorFlash)),
                     at: CGPoint(x: cx, y: cy + r + 20))
        }

        // ── Replanning — a new route grows from the fracture ──
        if st == .replanning {
            let elapsed = now.timeIntervalSince(stateEnteredAt)
            let frac = min(1.0, max(0.0, elapsed / 1.8))
            let r = minDim * 0.30
            let gapCenter = -Double.pi / 2 + 0.6
            let startP = CGPoint(x: cx + cos(gapCenter + 0.16) * r,
                                 y: cy + sin(gapCenter + 0.16) * r)
            let ctrl1 = CGPoint(x: startP.x + 70, y: startP.y - 40)
            let ctrl2 = CGPoint(x: startP.x + 110, y: startP.y + 30)
            let endP = CGPoint(x: cx + cos(gapCenter + 1.2) * r,
                               y: cy + sin(gapCenter + 1.2) * r)
            var grow = Path()
            grow.move(to: startP)
            let stepsN = 40
            for k in 1...stepsN {
                let u = Double(k) / Double(stepsN)
                if u > frac { break }
                let mt = 1 - u
                let x = mt * mt * mt * startP.x + 3 * mt * mt * u * ctrl1.x
                    + 3 * mt * u * u * ctrl2.x + u * u * u * endP.x
                let y = mt * mt * mt * startP.y + 3 * mt * mt * u * ctrl1.y
                    + 3 * mt * u * u * ctrl2.y + u * u * u * endP.y
                grow.addLine(to: CGPoint(x: x, y: y))
            }
            ctx.stroke(grow, with: .color(Palette.accent), lineWidth: 1.8)
            ctx.draw(Text("REPLANNING").font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Palette.accent),
                     at: CGPoint(x: cx, y: cy + r + 20))
        }

        // ── Verification sweep ──
        if st == .verifying {
            let sweep = (t.truncatingRemainder(dividingBy: 2.2)) / 2.2
            let a0: Angle = .radians(sweep * .pi * 2)
            let a1: Angle = .radians(sweep * .pi * 2 + 1.8)
            var arc = Path()
            arc.addArc(center: center, radius: minDim * 0.32, startAngle: a0, endAngle: a1, clockwise: false)
            ctx.stroke(arc, with: .color(Palette.accent.opacity(0.9)), lineWidth: 2)
            ctx.draw(Text("VERIFYING").font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Palette.accent),
                     at: CGPoint(x: cx, y: cy + minDim * 0.32 + 16))
        }

        // ── Verification seal — the signature lock-in ──
        if let sealStart = sealEnteredAt, engine.verification == .passed {
            let prog = min(1.0, now.timeIntervalSince(sealStart) / 1.2)
            let eased = 1 - pow(1 - prog, 3)
            let r = minDim * 0.30
            var ring = Path()
            ring.addArc(center: center, radius: r,
                        startAngle: .radians(-Double.pi / 2),
                        endAngle: .radians(-Double.pi / 2 + .pi * 2 * eased),
                        clockwise: false)
            ctx.stroke(ring, with: .color(Palette.seal), lineWidth: 1.6)
            if prog >= 0.999 {
                for k in 0..<16 {
                    let ang = Double(k) / 16 * .pi * 2
                    let inner = r + 4, outer = r + 8
                    var tick = Path()
                    tick.move(to: CGPoint(x: cx + cos(ang) * inner, y: cy + sin(ang) * inner))
                    tick.addLine(to: CGPoint(x: cx + cos(ang) * outer, y: cy + sin(ang) * outer))
                    ctx.stroke(tick, with: .color(Palette.seal.opacity(0.6)), lineWidth: 1)
                }
                ctx.draw(Text("✓ VERIFIED").font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Palette.seal),
                         at: CGPoint(x: cx, y: cy - r - 14))
            }
        }

        // ── Action trajectory — past dim, now sharp, future outlined ──
        if !steps.isEmpty {
            let baseY = h - 44
            let x0 = w * 0.10, x1 = w * 0.90
            let count = steps.count
            let gap = count > 1 ? (x1 - x0) / Double(count - 1) : 0

            for i in 0..<count {
                let step = steps[i]
                let px = count > 1 ? x0 + gap * Double(i) : (x0 + x1) / 2
                let status = step.status

                // segment to previous node
                if i > 0 {
                    let prevStep = steps[i - 1]
                    let prevX = x0 + gap * Double(i - 1)
                    var seg = Path()
                    seg.move(to: CGPoint(x: prevX, y: baseY))
                    if prevStep.status == "failed" {
                        seg.addLine(to: CGPoint(x: prevX + gap * 0.68, y: baseY))
                        ctx.stroke(seg, with: .color(Palette.critical.opacity(0.8)), lineWidth: 1.6)
                        // fracture marker
                        let fx = prevX + gap * 0.74
                        let s2: Double = 4
                        var xa = Path()
                        xa.move(to: CGPoint(x: fx - s2, y: baseY - s2))
                        xa.addLine(to: CGPoint(x: fx + s2, y: baseY + s2))
                        var xb = Path()
                        xb.move(to: CGPoint(x: fx + s2, y: baseY - s2))
                        xb.addLine(to: CGPoint(x: fx - s2, y: baseY + s2))
                        ctx.stroke(xa, with: .color(Palette.critical), lineWidth: 1.6)
                        ctx.stroke(xb, with: .color(Palette.critical), lineWidth: 1.6)
                        var rest = Path()
                        rest.move(to: CGPoint(x: fx + gap * 0.20, y: baseY))
                        rest.addLine(to: CGPoint(x: px, y: baseY))
                        ctx.stroke(rest, with: .color(Color.white.opacity(0.15)),
                                   style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                        continue
                    }
                    seg.addLine(to: CGPoint(x: px, y: baseY))
                    switch prevStep.status {
                    case "completed":
                        ctx.stroke(seg, with: .color(Palette.accent.opacity(0.35)), lineWidth: 1.4)
                    case "running":
                        ctx.stroke(seg,
                                   with: .color(Palette.accent),
                                   style: StrokeStyle(lineWidth: 1.8, dash: [5, 5],
                                                      dashPhase: CGFloat(-t * 22) * 1.0))
                    default:
                        ctx.stroke(seg, with: .color(Color.white.opacity(0.14)),
                                   style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    }
                }

                // node
                switch status {
                case "completed":
                    ctx.fill(circlePath(CGPoint(x: px, y: baseY), 3),
                             with: .color(Palette.accent.opacity(0.5)))
                case "running":
                    for g in [5.0, 8.5] {
                        ctx.stroke(circlePath(CGPoint(x: px, y: baseY), g),
                                   with: .color(Palette.accent.opacity(0.30 * pulse + 0.15)),
                                   lineWidth: 1)
                    }
                    ctx.fill(circlePath(CGPoint(x: px, y: baseY), 3.5), with: .color(Palette.accent))
                case "failed":
                    ctx.fill(circlePath(CGPoint(x: px, y: baseY), 3),
                             with: .color(Palette.critical.opacity(errorFlash)))
                default:
                    ctx.stroke(circlePath(CGPoint(x: px, y: baseY), 3),
                               with: .color(Color.white.opacity(0.30)), lineWidth: 1)
                }

                // label
                let shortTool = step.tool.isEmpty ? step.objective : step.tool
                let label = shortTool.count > 12 ? String(shortTool.prefix(11)) + "…" : shortTool
                let isNow = status == "running"
                ctx.draw(Text(label.uppercased())
                            .font(.system(size: 7.5, weight: isNow ? .bold : .regular, design: .monospaced))
                            .foregroundColor(isNow ? .white : Color.white.opacity(0.35)),
                         at: CGPoint(x: px, y: baseY + 14))
            }

            ctx.draw(Text("ACTION PATH").font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundColor(Palette.accent.opacity(0.55)),
                     at: CGPoint(x: w * 0.10, y: baseY - 16))
        }

        // ── Faint instrument annotations ──
        let elapsed = now.timeIntervalSince(stateEnteredAt)
        let hh = Int(elapsed) / 3600, mm = (Int(elapsed) % 3600) / 60, ss = Int(elapsed) % 60
        ctx.draw(Text(String(format: "T+%02d:%02d:%02d", hh, mm, ss))
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.22)),
                 at: CGPoint(x: 14, y: h - 12))
        ctx.draw(Text("SRC \(sources.count) · EVT \(engine.events.count) · \(st.rawValue)")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.22)),
                 at: CGPoint(x: w - 14, y: h - 12),
                 anchor: .trailing)
        ctx.draw(Text("NEXUS CORE")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.28)),
                 at: CGPoint(x: 14, y: 12),
                 anchor: .leading)
    }
}
