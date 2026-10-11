import AppKit

// Generates iconset: black plate, red triangle body, wireframe shell, vertex nodes, glow
let outDir = CommandLine.arguments[1]
let fm = FileManager.default
try? fm.removeItem(atPath: outDir)
try! fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func drawIcon(size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext
    let S = size

    // --- plate: deep black with subtle vertical gradient ---
    let plate = CGRect(x: 0, y: 0, width: S, height: S)
    let platePath = NSBezierPath(roundedRect: plate, xRadius: S * 0.2237, yRadius: S * 0.2237)
    NSColor.black.setFill()
    platePath.fill()
    ctx.saveGState()
    platePath.addClip()
    let grad = NSGradient(starting: NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.12, alpha: 1),
                          ending: NSColor(calibratedRed: 0.02, green: 0.02, blue: 0.024, alpha: 1))
    grad?.draw(in: plate, angle: -90)
    ctx.restoreGState()

    // faint inner stroke
    NSColor(calibratedRed: 1, green: 0.18, blue: 0.14, alpha: 0.10).setStroke()
    platePath.lineWidth = S * 0.006
    platePath.stroke()

    let cx = S / 2, cy = S / 2
    let side = S * 0.46
    let hh = side * 0.866
    let apex = NSPoint(x: cx, y: cy + hh * 0.30)
    let bl = NSPoint(x: cx - side / 2, y: cy - hh * 0.34)
    let br = NSPoint(x: cx + side / 2, y: cy - hh * 0.34)

    func bodyPath(s: CGFloat, lift: CGFloat) -> NSBezierPath {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: cx, y: cy + s * 0.866 * 0.34 + lift))
        p.line(to: NSPoint(x: cx - s / 2, y: cy - s * 0.866 * 0.30 + lift))
        p.line(to: NSPoint(x: cx + s / 2, y: cy - s * 0.866 * 0.30 + lift))
        p.close()
        return p
    }
    _ = apex; _ = bl; _ = br

    // --- glow behind body ---
    let glowPath = bodyPath(s: side, lift: 0)
    ctx.saveGState()
    glowPath.addClip()
    let glow = NSGradient(starting: NSColor(calibratedRed: 1, green: 0.24, blue: 0.16, alpha: 0.55),
                          ending: NSColor(calibratedRed: 1, green: 0.24, blue: 0.16, alpha: 0.0))
    glow?.draw(from: NSPoint(x: cx, y: cy + hh), to: NSPoint(x: cx, y: cy - hh), options: [])
    ctx.restoreGState()

    // --- outer wireframe shell: same triangle, scaled up 1.22, dashed, tilted ---
    ctx.saveGState()
    ctx.translateBy(x: cx, y: cy)
    ctx.rotate(by: .pi / 12)
    ctx.translateBy(x: -cx, y: -cy)
    let shell = bodyPath(s: side * 1.22, lift: 0)
    let shellInset = shell.copy() as! NSBezierPath
    let shellPath = shellInset
    shellPath.lineWidth = S * 0.012
    let dash: [CGFloat] = [S * 0.075, S * 0.055]
    shellPath.setLineDash(dash, count: dash.count, phase: 0)
    NSColor(calibratedRed: 1, green: 0.35, blue: 0.28, alpha: 0.65).setStroke()
    shellPath.stroke()
    ctx.restoreGState()

    // --- solid body with vertical gradient ---
    let body = bodyPath(s: side, lift: 0)
    ctx.saveGState()
    body.addClip()
    let bodyGrad = NSGradient(starting: NSColor(calibratedRed: 1.0, green: 0.30, blue: 0.24, alpha: 1),
                              ending: NSColor(calibratedRed: 0.72, green: 0.06, blue: 0.10, alpha: 1))
    bodyGrad?.draw(in: body.bounds, angle: -90)
    // top hot edge
    NSColor(calibratedRed: 1, green: 0.72, blue: 0.62, alpha: 0.9).setStroke()
    let hot = NSBezierPath()
    hot.move(to: NSPoint(x: cx - side / 2, y: cy - side * 0.866 * 0.30))
    hot.line(to: NSPoint(x: cx, y: cy + side * 0.866 * 0.34))
    hot.line(to: NSPoint(x: cx + side / 2, y: cy - side * 0.866 * 0.30))
    hot.lineWidth = S * 0.008
    hot.stroke()
    ctx.restoreGState()

    // --- inner core: small pale triangle ---
    let coreS = side * 0.42
    let core = bodyPath(s: coreS, lift: S * 0.018)
    NSColor(calibratedRed: 1, green: 0.88, blue: 0.80, alpha: 0.92).setFill()
    core.fill()

    // --- vertex nodes ---
    let nodeR = S * 0.016
    for p in [NSPoint(x: cx, y: cy + side * 0.866 * 0.34),
              NSPoint(x: cx - side / 2, y: cy - side * 0.866 * 0.30),
              NSPoint(x: cx + side / 2, y: cy - side * 0.866 * 0.30)] {
        let dot = NSBezierPath(ovalIn: NSRect(x: p.x - nodeR, y: p.y - nodeR, width: nodeR * 2, height: nodeR * 2))
        NSColor.white.setFill()
        dot.fill()
    }

    // --- vertex shadow under plate ---
    img.unlockFocus()
    return img
}

// render required sizes
let iconSizes: [(px: Int, name: String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]
for (px, name) in iconSizes {
    let img = drawIcon(size: CGFloat(px))
    guard let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        print("FAIL \(name)"); exit(1)
    }
    try! png.write(to: URL(fileURLWithPath: outDir + "/" + name))
}
print("iconset ok -> \(outDir)")
