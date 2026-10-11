// Nexus Triangl - companion prototype
// Red samaritan triangle

import Cocoa
import Carbon
import ServiceManagement

// states

enum TriState: String {
    case idle, lock, reasoning, executing, verified, blocked
    var label: String {
        switch self {
        case .idle:      return "FOLLOWING POINTER · AWAITING INTENT"
        case .lock:      return "TARGET ACQUIRED"
        case .reasoning: return "CONTEXT UNDERSTOOD"
        case .executing: return "EXECUTING"
        case .verified:  return "VERIFIED"
        case .blocked:   return "BLOCKED"
        }
    }
}

@MainActor
final class State {
    static let shared = State()
    var on: Bool = true {
        didSet { overlay?.isVisible = on }
    }
    var overlay: OverlayController?
    var lens: LensController?
    func set(_ s: TriState) { overlay?.setState(s); lens?.reflectState(s) }
    func set(_ s: TriState, _ detail: String) { overlay?.setState(s); lens?.reflectState(s, detail) }
}

// Mark:- Triangle View

final class TriangleView: NSView {

    let tri = CAShapeLayer()
    let ring = CAShapeLayer()
    let traj = CAShapeLayer()
    let bracket = CAShapeLayer()
    let check = CATextLayer()
    let dots = CALayer()
    private var dotLayers: [CAShapeLayer] = []

    var state: TriState = .idle {
        didSet { apply(state) }
    }
    var bracketFrame: CGRect? {
        didSet { layoutBracket() }
    }
    var trajEnd: CGPoint? {
        didSet { layoutTraj() }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        tri.path = Self.triangle(side: 20)
        tri.fillColor = NSColor(calibratedRed: 1.0, green: 0.15, blue: 0.13, alpha: 1).cgColor
        tri.shadowRadius = 9
        tri.shadowOpacity = 0.9
        tri.shadowOffset = .zero
        tri.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer?.addSublayer(tri)

        bracket.strokeColor = NSColor(calibratedRed: 1, green: 0.25, blue: 0.2, alpha: 0.95).cgColor
        bracket.lineWidth = 1.4
        bracket.fillColor = nil
        bracket.isHidden = true
        layer?.addSublayer(bracket)

   traj.strokeColor = NSColor(calibratedRed: 1, green: 0.3, blue: 0.25, alpha: 0.8).cgColor
        traj.lineWidth = 1.1
        traj.lineDashPattern = [4, 4]
        traj.fillColor = nil
        traj.isHidden = true
        layer?.addSublayer(traj)

        ring.strokeColor = NSColor(calibratedRed: 1, green: 0.4, blue: 0.35, alpha: 1).cgColor
        ring.lineWidth = 1.2
        ring.fillColor = nil
        ring.isHidden = true
        layer?.addSublayer(ring)

        check.string = "✓"
        check.fontSize = 13
        check.fontSize = 13
        check.foregroundColor = NSColor.white.cgColor
        check.alignmentMode = .center
        check.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        check.isHidden = true
        layer?.addSublayer(check)

        dots.isHidden = true
        layer?.addSublayer(dots)
        for _ in 0..<3 {
            let d = CAShapeLayer()
            d.path = NSBezierPath(ovalIn: NSRect(x: -1.6, y: -1.6, width: 3.2, height: 3.2)).cgPath
            guard let c = NSColor(calibratedRed: 1, green: 0.3, blue: 0.25, alpha: 1).cgColor.copy(alpha: 0.9) else { continue }
            d.fillColor = NSColor(calibratedRed: 1, green: 0.3, blue: 0.25, alpha: 0.9).cgColor
            d.shadowColor = c
            d.shadowRadius = 3
            d.shadowOpacity = 1
            dots.addSublayer(d)
            dotLayers.append(d)
        }
        apply(.idle)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    static func triangle(side: CGFloat) -> CGPath {
        let h = side * 0.866
        let p = NSBezierPath()
        p.move(to: NSPoint(x: 0, y: h * 0.62))
        p.line(to: NSPoint(x: -side / 2, y: -h * 0.38))
        p.line(to: NSPoint(x: side / 2, y: -h * 0.38))
        p.close()
        return p.cgPath
    }

    override func layout() {
        super.layout()
        tri.position = NSPoint(x: bounds.midX, y: bounds.midY)
    }

    private func animate(_ layer: CAShapeLayer, _ key: String, _ from: CGFloat, _ to: CGFloat, dur: CFTimeInterval = 0.9, repeat_: Float = 0, timing: CAMediaTimingFunction = .init(name: .easeOut)) {
        let a = CABasicAnimation(keyPath: key)
        a.fromValue = from
        a.toValue = to
        a.duration = dur
        a.repeatCount = repeat_
        a.timingFunction = timing
        a.isRemovedOnCompletion = true
        layer.add(a, forKey: key)
    }

    private func apply(_ s: TriState) {
        tri.removeAllAnimations()
        ring.removeAllAnimations()
        traj.removeAllAnimations()
        dots.isHidden = true
        for d in dotLayers { d.removeAllAnimations() }

        tri.shadowOpacity = 0.9
        tri.shadowRadius = 9
        check.isHidden = true
        ring.isHidden = true
        traj.isHidden = true
        bracket.isHidden = (s == .idle)

        switch s {
        case .idle:
            tri.fillColor = NSColor(calibratedRed: 1.0, green: 0.15, blue: 0.13, alpha: 1).cgColor
            animate(tri, "transform.scale", 1.0, 1.06, dur: 1.4, repeat_: .greatestFiniteMagnitude, timing: .init(name: .easeInEaseOut))
        case .lock:
            tri.fillColor = NSColor(calibratedRed: 1.0, green: 0.2, blue: 0.16, alpha: 1).cgColor
            layoutBracket()
            animate(tri, "transform.scale", 1.0, 1.12, dur: 0.7, repeat_: .greatestFiniteMagnitude, timing: .init(name: .easeInEaseOut))
        case .reasoning:
            tri.fillColor = NSColor(calibratedRed: 1.0, green: 0.3, blue: 0.24, alpha: 1).cgColor
            animate(tri, "transform.scale", 0.82, 1.18, dur: 0.62, repeat_: .greatestFiniteMagnitude, timing: .init(name: .easeInEaseOut))
            dots.isHidden = false
            layoutDots()
        case .executing:
            tri.fillColor = NSColor(calibratedRed: 1.0, green: 0.45, blue: 0.35, alpha: 1).cgColor
            layoutTraj()
            if traj.path != nil {
                let dash = CABasicAnimation(keyPath: "lineDashPhase")
                dash.fromValue = 8
                dash.toValue = 0
                dash.duration = 0.5
                dash.repeatCount = .greatestFiniteMagnitude
                traj.add(dash, forKey: "dash")
            }
        case .verified:
            tri.fillColor = NSColor(calibratedRed: 1.0, green: 0.85, blue: 0.8, alpha: 1).cgColor
            check.isHidden = false
            layoutCheck()
            ring.isHidden = false
            layoutRing(expand: true)
            animate(ring, "transform.scale", 0.35, 2.1, dur: 0.75)
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 1
            fade.toValue = 0
            fade.duration = 0.75
            ring.add(fade, forKey: "fade")
        case .blocked:
            tri.fillColor = NSColor(calibratedRed: 0.45, green: 0.08, blue: 0.08, alpha: 1).cgColor
            tri.shadowOpacity = 0.2
            _ = animateBlocked
        }
    }

    private var animateBlocked: Int {
        let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shake.values = [-3, 3, -2, 2, 0]
        shake.duration = 0.45
        tri.add(shake, forKey: "shake")
        return 0
    }

    private func center() -> NSPoint { NSPoint(x: bounds.midX, y: bounds.midY) }

    private func layoutBracket() {
        guard let f = bracketFrame else { return }
        let c = center()
        let r = NSRect(x: c.x + (f.midX - c.x) - f.width / 2 - 4,
                       y: c.y + (f.midY - c.y) - f.height / 2 - 4,
                       width: f.width + 8, height: f.height + 8)
        let len: CGFloat = min(9, r.width / 3, r.height / 3)
        let p = NSBezierPath()
        // four corners
        p.move(to: NSPoint(x: r.minX + len, y: r.minY));        p.line(to: NSPoint(x: r.minX, y: r.minY));        p.line(to: NSPoint(x: r.minX, y: r.minY + len))
        p.move(to: NSPoint(x: r.maxX - len, y: r.minY));        p.line(to: NSPoint(x: r.maxX, y: r.minY));        p.line(to: NSPoint(x: r.maxX, y: r.minY + len))
        p.move(to: NSPoint(x: r.minX + len, y: r.maxY));        p.line(to: NSPoint(x: r.minX, y: r.maxY));        p.line(to: NSPoint(x: r.minX, y: r.maxY - len))
        p.move(to: NSPoint(x: r.maxX - len, y: r.maxY));        p.line(to: NSPoint(x: r.maxX, y: r.maxY));        p.line(to: NSPoint(x: r.maxX, y: r.maxY - len))
        bracket.path = p.cgPath
        bracket.isHidden = (state == .idle)
    }

    private func layoutTraj() {
        guard let end = trajEnd else { return }
        let c = center()
        let p = NSBezierPath()
        p.move(to: c)
        p.line(to: NSPoint(x: c.x + (end.x - c.x), y: c.y + (end.y - c.y)))
        traj.path = p.cgPath
        traj.isHidden = (state != .executing)
    }

    private func layoutRing(expand: Bool) {
        let c = center()
        ring.position = c
        ring.path = NSBezierPath(ovalIn: NSRect(x: -14, y: -14, width: 28, height: 28)).cgPath
    }

    private func layoutCheck() {
        check.position = center()
        check.bounds = NSRect(x: 0, y: 0, width: 16, height: 16)
        check.anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }

    private func layoutDots() {
        let c = center()
        for (i, d) in dotLayers.enumerated() {
            d.position = c
            let angle = (Double(i) / 3.0) * .pi * 2
            let orbit = CABasicAnimation(keyPath: "position")
            orbit.fromValue = NSPoint(x: c.x + 18 * cos(angle), y: c.y + 18 * sin(angle))
            orbit.toValue = NSPoint(x: c.x + 26 * cos(angle + .pi / 1.6), y: c.y + 26 * sin(angle + .pi / 1.6))
            orbit.duration = 0.62
            orbit.autoreverses = true
            orbit.repeatCount = .greatestFiniteMagnitude
            orbit.timingFunction = .init(name: .easeInEaseOut)
            d.add(orbit, forKey: "orbit")
        }
    }
}

// MARK: - Overlay Controller (triangle follows cursor)

@MainActor
final class OverlayController {

    let panel: NSPanel
    let triView = TriangleView()
    private var timer: Timer?
    private(set) var pos: NSPoint = NSEvent.mouseLocation
    private var mouse: NSPoint = NSEvent.mouseLocation
    private var angle: CGFloat = 0

    // target acquisition
    private var dwellElem: String? = nil
    private var dwellStart: Date = .distantPast
    private var lastLockKey: String? = nil

    init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 120, height: 120),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.contentView = triView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.cursorWindow)))
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.orderFrontRegardless()
        pos = NSEvent.mouseLocation
        panel.setFrameOrigin(NSPoint(x: pos.x - 60, y: pos.y - 60))
        State.shared.overlay = self
        setState(.idle)
    }

    @MainActor var isVisible: Bool = true {
        didSet {
            if isVisible { panel.orderFrontRegardless() } else { panel.orderOut(nil) }
        }
    }

    var agentActive = false
    var execTarget: CGPoint? {
        didSet {
            guard let t = execTarget else { triView.trajEnd = nil; return }
            let o = panel.frame.origin
            triView.trajEnd = NSPoint(x: t.x - o.x, y: (NSScreen.screens.first?.frame.height ?? 1117) - t.y - o.y)
        }
    }

    func setState(_ s: TriState) {
        triView.state = s
    }

    func start() {
        timer = Timer(timeInterval: 1.0 / 90.0, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func tick() {
        let m = NSEvent.mouseLocation
        mouse = m
        let tx = m.x + 15, ty = m.y - 1
        let dt: CGFloat = 1.0 / 60.0
        let k = 1 - exp(-dt * 14)
        pos.x += (tx - pos.x) * k
        pos.y += (ty - pos.y) * k
        angle += (tiltAngle(dx: tx - (pos.x - (tx - (tx - pos.x)) * 0), dy: 0) - angle) * k
        panel.setFrameOrigin(NSPoint(x: pos.x - 60, y: pos.y - 60))

        // hover target acquisition (throttled) — paused while the agent drives
        if !agentActive && Date().timeIntervalSince(dwellStart) > 0.25 {
            dwellStart = Date()
            let ax = axPoint(mouse)
            if let el = elementAt(ax) {
                let frame = el.frame
                let key = el.label + String(describing: frame.origin)
                if key != lastLockKey {
                    lastLockKey = key
                    triView.bracketFrame = frame
                    triView.trajEnd = nil
                    if triView.state == .idle { setState(.lock) }
                    State.shared.lens?.reflectTarget(el.label)
                }
            } else if lastLockKey != "none" {
                lastLockKey = "none"
                triView.bracketFrame = nil
                if triView.state == .lock { setState(.idle) }
                State.shared.lens?.reflectTarget(nil)
            }
        }
    }

    private func tiltAngle(dx: CGFloat, dy: CGFloat) -> CGFloat {
        let v = hypot(dx, dy)
        guard v > 0.5 else { return 0 }
        let a = atan2(dy, dx)
        let turn = a - .pi / 2
        let clamped = max(-0.4, min(0.4, turn))
        return clamped
    }

    private func axPoint(_ p: NSPoint) -> NSPoint {
        let h = NSScreen.screens.first?.frame.height ?? CGFloat(UINT32_MAX)
        return NSPoint(x: p.x, y: h - p.y)
    }
}

// MARK: - Accessibility (element under cursor)

struct AXElement {
    let frame: CGRect
    let label: String
}

func elementAt(_ p: NSPoint) -> AXElement? {
    guard AXIsProcessTrusted() else { return nil }
    let system = AXUIElementCreateSystemWide()
    var el: AXUIElement?
    let err = AXUIElementCopyElementAtPosition(system, Float(p.x), Float(p.y), &el)
    guard err == .success, let el = el as AXUIElement? else { return nil }
    var posVal: AnyObject?
    var sizeVal: AnyObject?
    AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &posVal)
    AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &sizeVal)
    var pt = CGPoint.zero, sz = CGSize.zero
    if let v = posVal, CFGetTypeID(v) == AXValueGetTypeID() {
        let av = v as! AXValue
        AXValueGetValue(av, .cgPoint, &pt)
    }
    if let v = sizeVal, CFGetTypeID(v) == AXValueGetTypeID() {
        let av = v as! AXValue
        AXValueGetValue(av, .cgSize, &sz)
    }
    var titleV: AnyObject?
    var roleV: AnyObject?
    AXUIElementCopyAttributeValue(el, kAXTitleAttribute as CFString, &titleV)
    AXUIElementCopyAttributeValue(el, kAXRoleDescriptionAttribute as CFString, &roleV)
    let label = (titleV as? String)?.isEmpty == false ? (titleV as! String) : (roleV as? String) ?? "ELEMENT"
    return AXElement(frame: CGRect(x: pt.x, y: pt.y, width: sz.width, height: sz.height), label: label)
}

// MARK: - File Search (Spotlight)

struct FileRow {
    let name: String
    let url: URL
    let date: Date?
}

@MainActor
final class FileSearch: NSObject, NSMetadataQueryDelegate {
    private let query = NSMetadataQuery()
    private var done: (([FileRow]) -> Void)?
    private var tokens: [String] = []

    private static let stopwords: Set<String> = [
        "the", "a", "an", "of", "for", "me", "my", "mine", "i", "it", "its", "in", "on", "at", "to", "from",
        "was", "were", "is", "are", "and", "or", "with", "about", "please", "find", "search", "locate", "show",
        "get", "give", "where", "that", "this", "last", "latest", "recent", "recently", "yesterday", "today",
        "containing", "contains", "file", "files", "folder", "directory", "named", "called", "open", "reveal",
        "have", "has", "had", "let", "can", "you", "some", "any", "all", "new", "old", "oldest", "one", "two"
    ]

    override init() {
        super.init()
        query.delegate = self
        query.searchScopes = [URL(fileURLWithPath: NSHomeDirectory())]
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(finished(_:)),
                                               name: Notification.Name("NSMetadataQueryDidFinishGatheringNotification"),
                                               object: query)
    }

    private func extractTokens(_ text: String) -> [String] {
        let base = text.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.lowercased() }
        var core = base.filter { $0.count >= 2 && !Self.stopwords.contains($0) }
        if core.isEmpty { core = base.filter { $0.count >= 2 } }
        return Array(Set(core))
    }

    @MainActor func run(_ text: String, completion: @escaping ([FileRow]) -> Void) {
        tokens = extractTokens(text)
        if tokens.isEmpty { completion([]); return }
        done = completion
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.query.stop()
            let predicateString = self.tokens.map { token in
                "(kMDItemFSName CONTAINS[cd] '\(token)' OR kMDItemDisplayName CONTAINS[cd] '\(token)' OR kMDItemTextContent CONTAINS[cd] '\(token)')"
            }.joined(separator: " OR ")
            self.query.predicate = NSPredicate(format: predicateString)
            if !self.query.start() { self.fallbackScan() }
        }
    }

    @objc private func finished(_ note: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self = self else { return }
            self.query.disableUpdates()
            self.query.stop()
            let items = self.query.results as? [NSMetadataItem] ?? []
            let rows: [FileRow] = items.prefix(120).compactMap { item in
                guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { return nil }
                let name = item.value(forAttribute: NSMetadataItemFSNameKey) as? String ?? url.lastPathComponent
                let date = item.value(forAttribute: NSMetadataItemContentModificationDateKey) as? Date
                return FileRow(name: name, url: url, date: date)
            }
            let ranked = self.rank(rows)
            if ranked.isEmpty { self.fallbackScan() } else { self.done?(Array(ranked.prefix(12))) }
        }
    }

    private func rank(_ rows: [FileRow]) -> [FileRow] {
        rows.map { row -> (FileRow, Int) in
            let n = row.name.lowercased()
            var score = tokens.filter { n.contains($0) }.count * 10
            if row.url.path.contains("/Desktop/") { score += 1 }
            return (row, score)
        }
        .sorted { (a, b) in
            a.1 != b.1 ? a.1 > b.1 : (a.0.date ?? .distantPast) > (b.0.date ?? .distantPast)
        }
        .map { $0.0 }
    }

    private func fallbackScan() {
        let fm = FileManager.default
        var roots: [URL] = []
        for name in ["Desktop", "Documents", "Downloads", "Pictures", "Movies", "Music"] {
            let u = fm.homeDirectoryForCurrentUser.appendingPathComponent(name)
            if fm.fileExists(atPath: u.path) { roots.append(u) }
        }
        guard !roots.isEmpty, !tokens.isEmpty else { done?([]); return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var found: [FileRow] = []
            var visited = 0
            for root in roots {
                let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [URLResourceKey.contentModificationDateKey])
                while let url = enumerator?.nextObject() as? URL {
                    if visited > 30000 { break }
                    visited += 1
                    let n = url.lastPathComponent.lowercased()
                    guard n.contains(".ds_store") == false else { continue }
                    if self.tokens.contains(where: { n.contains($0) }) {
                        let d = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? nil
                        found.append(FileRow(name: url.lastPathComponent, url: url, date: d))
                        if found.count >= 60 { break }
                    }
                }
            }
            let byDate = found.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
            DispatchQueue.main.async { self.done?(Array(byDate.prefix(12))) }
        }
    }
}


// MARK: - Command Field

final class CommandField: NSTextField {
    var onEsc: (() -> Void)?
    var onSubmit: (() -> Void)?
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onEsc?() }
        else if event.keyCode == 36 { onSubmit?() }
        else { super.keyDown(with: event) }
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.keyCode == 53 { onEsc?(); return true }
        if event.keyCode == 36 { onSubmit?(); return true }
        return super.performKeyEquivalent(with: event)
    }
}

// MARK: - Lens Panel

final class LensPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

// MARK: - Lens Controller

@MainActor
final class LensController: NSObject, NSTextFieldDelegate {

    private let panel: LensPanel
    private let titleLabel = NSTextField(labelWithString: "NEXUS")
    private let subLabel = NSTextField(labelWithString: "COMMAND")
    private let stateLabel = NSTextField(labelWithString: "")
    private let field = CommandField()
    private let stack = NSStackView()
    private let hint = NSTextField(labelWithString: "⏎ execute   ·   esc dismiss   ·   ⌘P pin")
    private var closeBtn: NSButton!
    private var rows: [FileRow] = []
    private let searcher = FileSearch()
    private var appCache: [(String, URL)]?
    private var pendingQuery: String = ""
    private var followTimer: Timer?
    private var keyMonitor: Any?
    private(set) var pinned = false
    private(set) var isRecording = false
    private(set) var isReplaying = false
    private var macroName = ""
    private var clipper: Timer?
    private var clips: [String] = []
    private var clipRows: [String] = []
    private var lastClipCount = 0
    private var previousApp: NSRunningApplication?
    private(set) var isOpen = false

    static let width: CGFloat = 370

    override init() {
        panel = LensPanel(contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 104),
                          styleMask: [.borderless, .fullSizeContentView],
                          backing: .buffered, defer: false)
        super.init()
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = false
        build()
        State.shared.lens = self
    }

    private func build() {
        guard let content = panel.contentView else { return }
        content.wantsLayer = true
        content.layer?.cornerRadius = 14
        content.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.92).cgColor
        content.layer?.borderColor = NSColor(calibratedRed: 1, green: 0.22, blue: 0.18, alpha: 0.6).cgColor
        content.layer?.borderWidth = 1
        content.layer?.masksToBounds = true

        titleLabel.font = .monospacedSystemFont(ofSize: 12, weight: .bold)
        titleLabel.textColor = NSColor(calibratedRed: 1, green: 0.24, blue: 0.2, alpha: 1)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(titleLabel)

        subLabel.font = .monospacedSystemFont(ofSize: 9, weight: .regular)
        subLabel.textColor = NSColor(calibratedRed: 1, green: 0.45, blue: 0.4, alpha: 0.85)
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(subLabel)

        stateLabel.font = .monospacedSystemFont(ofSize: 9, weight: .regular)
        stateLabel.textColor = NSColor(calibratedRed: 1, green: 0.55, blue: 0.5, alpha: 0.95)
        stateLabel.alignment = .right
        stateLabel.lineBreakMode = .byTruncatingTail
        stateLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stateLabel)

        field.font = .systemFont(ofSize: 14)
        field.textColor = .white
        field.backgroundColor = NSColor.white.withAlphaComponent(0.07)
        field.isBordered = false
        field.focusRingType = .none
        field.placeholderString = "Find a file · open an app · reveal in Finder…"
        field.delegate = self
        field.onEsc = { [weak self] in self?.close() }
        field.onSubmit = { [weak self] in self?.submit() }
        field.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(field)

        closeBtn = NSButton(title: "✕", target: self, action: #selector(doClose))
        closeBtn.font = .monospacedSystemFont(ofSize: 11, weight: .bold)
        closeBtn.isBordered = false
        closeBtn.contentTintColor = NSColor(white: 0.6, alpha: 1)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(closeBtn)

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        hint.font = .monospacedSystemFont(ofSize: 8.5, weight: .regular)
        hint.textColor = NSColor(white: 0.55, alpha: 1)
        hint.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(hint)

        NSLayoutConstraint.activate([
            titleLabel.leftAnchor.constraint(equalTo: content.leftAnchor, constant: 14),
            titleLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            subLabel.leftAnchor.constraint(equalTo: titleLabel.rightAnchor, constant: 8),
            subLabel.lastBaselineAnchor.constraint(equalTo: titleLabel.lastBaselineAnchor),
            stateLabel.rightAnchor.constraint(equalTo: content.rightAnchor, constant: -30),
            stateLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            stateLabel.leftAnchor.constraint(greaterThanOrEqualTo: subLabel.rightAnchor, constant: 10),
            closeBtn.rightAnchor.constraint(equalTo: content.rightAnchor, constant: -10),
            closeBtn.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeBtn.widthAnchor.constraint(equalToConstant: 18),
            field.leftAnchor.constraint(equalTo: content.leftAnchor, constant: 12),
            field.rightAnchor.constraint(equalTo: content.rightAnchor, constant: -12),
            field.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            field.heightAnchor.constraint(equalToConstant: 32),
            stack.leftAnchor.constraint(equalTo: content.leftAnchor, constant: 12),
            stack.rightAnchor.constraint(equalTo: content.rightAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: field.bottomAnchor, constant: 8),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: hint.topAnchor, constant: -6),
            hint.leftAnchor.constraint(equalTo: content.leftAnchor, constant: 14),
            hint.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -10)
        ])
    }

    // MARK: window lifecycle

    func toggle() { isOpen ? close() : open() }

    func open() {
        rows = []; rebuildRows(); resize(0)
        field.stringValue = ""
        reflectState(.idle)
        previousApp = NSWorkspace.shared.frontmostApplication
        isOpen = true
        panel.setFrameOrigin(positionForHeight(104))
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(field)
        NSApp.activate(ignoringOtherApps: true)
        startFollow()
        startKeyMonitor()
        if clipper == nil {
            loadClips()
            clipper = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in self?.pollClips() }
            RunLoop.main.add(clipper!, forMode: .common)
        }
    }

    func close() {
        agentAbort()
        isOpen = false
        pinned = false
        stopFollow()
        stopKeyMonitor()
        panel.orderOut(nil)
    }

    @objc private func doClose() { close() }

    func togglePin() {
        pinned.toggle()
        hint.stringValue = pinned
            ? "▮ PINNED — esc dismiss   ·   ⌘P unpin"
            : "⏎ execute   ·   esc dismiss   ·   ⌘P pin"
        if !pinned { followTick() }
    }

    private func startKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            if event.keyCode == 53 { self.close(); return nil }
            if event.keyCode == 35, event.modifierFlags.contains(.command) { self.togglePin(); return nil }
            return event
        }
    }

    private func stopKeyMonitor() {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }

    private func anchorPoint() -> NSPoint {
        State.shared.overlay?.pos ?? NSEvent.mouseLocation
    }

    private func positionForHeight(_ h: CGFloat) -> NSPoint {
        let m = anchorPoint()
        let screen = NSScreen.screens.first(where: { $0.frame.contains(m) }) ?? NSScreen.main!
        let vf = screen.visibleFrame
        let w = Self.width
        var x = m.x + 18
        var y = m.y - h - 14
        if x + w > vf.maxX - 8 { x = m.x - w - 18 }
        x = max(vf.minX + 8, min(x, vf.maxX - w - 8))
        y = max(vf.minY + 8, min(y, vf.maxY - h - 8))
        return NSPoint(x: x, y: y)
    }

    private func resize(_ rowCount: Int) {
        let h: CGFloat = 104 + CGFloat(rowCount) * 48
        let f = panel.frame
        panel.setFrame(NSRect(origin: positionForHeight(h), size: NSSize(width: Self.width, height: h)), display: true, animate: false)
        _ = f
    }

    // MARK: follow the triangle

    private func startFollow() {
        guard followTimer == nil else { return }
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.followTick() }
        RunLoop.main.add(t, forMode: .common)
        followTimer = t
    }

    private func stopFollow() {
        followTimer?.invalidate()
        followTimer = nil
    }

    private func followTick() {
        guard isOpen, !pinned else { return }
        if State.shared.overlay?.agentActive == true { return }
        if isRecording { return }
        let o = positionForHeight(panel.frame.height)
        if o != panel.frame.origin { panel.setFrameOrigin(o) }
    }

    // MARK: macros (record & replay)

    func startRecording(_ name: String) {
        guard AXIsProcessTrusted() else {
            respond("PERMISSION REQUIRED — Accessibility (menu bar ▸ Grant Accessibility…)", .blocked)
            return
        }
        if isRecording { respond("ALREADY RECORDING — say stop first", .blocked); return }
        if isReplaying { respond("REPLAY IN PROGRESS", .blocked); return }
        macroName = name.isEmpty ? "macro-\(Int(Date().timeIntervalSince1970) % 100000)" : name
        if !MacroTap.start() { respond("EVENT TAP DENIED — grant Accessibility", .blocked); return }
        isRecording = true
        State.shared.overlay?.agentActive = true
        State.shared.set(.executing, "REC \(macroName) — move & click · stop to end")
        agentSteps = ["● REC \(macroName)", "say 'stop' to save · 'replay \(macroName)' to run"]
        rebuildSteps(); resize(2)
    }

    func stopRecording() {
        guard isRecording else { respond("NOTHING TO STOP", .blocked); return }
        isRecording = false
        State.shared.overlay?.agentActive = false
        let evs = MacroTap.stop()
        guard !evs.isEmpty else { respond("EMPTY RECORDING — nothing captured", .blocked); return }
        let m = Macro(name: macroName, events: evs)
        MacroStore.save(m)
        State.shared.set(.verified, "RECORDED \(macroName) — \(evs.count) events")
        agentSteps = ["✓ \(macroName) saved — \(evs.count) events", "replay \(macroName) to run it"]
        rebuildSteps(); resize(2)
    }

    func replayMacro(_ rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespaces).lowercased()
        guard !isRecording else { respond("RECORDING — say stop first", .blocked); return }
        guard let m = MacroStore.load(name) else {
            respond("NO MACRO '\(name)' — \(MacroStore.list().isEmpty ? "record one first" : MacroStore.list().joined(separator: ", "))", .blocked)
            return
        }
        guard AXIsProcessTrusted() else {
            respond("PERMISSION REQUIRED — Accessibility to replay", .blocked)
            return
        }
        isReplaying = true
        State.shared.overlay?.agentActive = true
        State.shared.set(.executing, "REPLAY \(m.name)")
        agentSteps = ["▶ \(m.name) — \(m.events.count) events"]
        rebuildSteps(); resize(1)
        let wasOpen = isOpen
        panel.orderOut(nil)
        let t0 = DispatchTime.now()
        for ev in m.events {
            DispatchQueue.main.asyncAfter(deadline: t0 + .milliseconds(Int(ev.t))) { [weak self] in self?.playOne(ev) }
        }
        let endMs = Int(m.events.last?.t ?? 0) + 80
        DispatchQueue.main.asyncAfter(deadline: t0 + .milliseconds(endMs)) { [weak self] in
            guard let self = self else { return }
            self.isReplaying = false
            State.shared.overlay?.agentActive = false
            State.shared.overlay?.execTarget = nil
            if wasOpen { self.panel.orderFrontRegardless(); self.panel.makeKeyAndOrderFront(nil) }
            self.respond("MACRO VERIFIED — \(m.name)", .verified)
        }
    }

    private func playOne(_ ev: MacroEvent) {
        let src = agentPostSource()
        switch ev.type {
        case "move":
            let p = CGPoint(x: ev.x, y: ev.y)
            if let e = CGEvent(mouseEventSource: src, mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left) {
                e.post(tap: .cghidEventTap)
            }
            State.shared.overlay?.execTarget = p
        case "md", "mu":
            let t: CGEventType = ev.type == "md" ? .leftMouseDown : .leftMouseUp
            if let e = CGEvent(mouseEventSource: src, mouseType: t, mouseCursorPosition: CGPoint(x: ev.x, y: ev.y), mouseButton: .left) {
                e.post(tap: .cghidEventTap)
            }
        case "key":
            if let e = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(ev.keyCode), keyDown: true) {
                e.flags = CGEventFlags(rawValue: UInt64(ev.flags))
                if !ev.text.isEmpty {
                    var units = Array(ev.text.utf16)
                    e.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
                }
                e.post(tap: .cghidEventTap)
            }
            if let e = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(ev.keyCode), keyDown: false) {
                e.post(tap: .cghidEventTap)
            }
        default: break
        }
    }

    // MARK: clipboard inbox

    private var clipsFile: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Nexus/clips.json")
    }

    private func loadClips() {
        if let d = try? Data(contentsOf: clipsFile),
           let a = try? JSONDecoder().decode([String].self, from: d) { clips = a }
        lastClipCount = NSPasteboard.general.changeCount
    }

    private func saveClips() {
        try? FileManager.default.createDirectory(at: clipsFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(clips).write(to: clipsFile)
    }

    private func pollClips() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastClipCount else { return }
        lastClipCount = pb.changeCount
        guard let s = pb.string(forType: .string) else { return }
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, t.count <= 2000 else { return }
        if clips.first != t {
            clips.insert(t, at: 0)
            if clips.count > 40 { clips.removeLast(clips.count - 40) }
            saveClips()
        }
    }

    private func runClipSearch(_ text: String) {
        let stop: Set<String> = ["clip", "clips", "clipboard", "the", "a", "an", "of", "for", "my", "find", "search", "show", "get"]
        let tokens = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 2 && !stop.contains($0) }
        let hits: [String]
        if tokens.isEmpty {
            hits = Array(clips.prefix(8))
        } else {
            hits = clips.filter { c in let n = c.lowercased(); return tokens.contains { n.contains($0) } }.prefix(8).map { $0 }
        }
        if hits.isEmpty { respond("CLIPBOARD EMPTY — no matches", .blocked); return }
        clipRows = hits
        rebuildClipRows()
        resize(hits.count)
        respond("CLIPS — \(hits.count)", .verified)
    }

    private func rebuildClipRows() {
        for v in stack.arrangedSubviews { stack.removeArrangedSubview(v); v.removeFromSuperview() }
        for (i, text) in clipRows.enumerated() { stack.addArrangedSubview(clipRow(text, index: i)) }
    }

    private func clipRow(_ text: String, index: Int) -> NSView {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: Self.width - 24, height: 34))
        let preview = String(text.replacingOccurrences(of: "\n", with: " ").prefix(64))
        let label = NSTextField(labelWithString: preview)
        label.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        label.textColor = .white
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        let copyBtn = NSButton(title: "COPY", target: self, action: #selector(clipCopy(_:)))
        let pasteBtn = NSButton(title: "PASTE", target: self, action: #selector(clipPaste(_:)))
        copyBtn.tag = index; pasteBtn.tag = index
        for b in [copyBtn, pasteBtn] {
            b.font = .monospacedSystemFont(ofSize: 8, weight: .bold)
            b.isBordered = false
            b.wantsLayer = true
            b.layer?.cornerRadius = 4
            b.layer?.borderWidth = 1
            b.layer?.borderColor = NSColor(calibratedRed: 1, green: 0.3, blue: 0.25, alpha: 0.7).cgColor
            b.contentTintColor = NSColor(calibratedRed: 1, green: 0.5, blue: 0.45, alpha: 1)
            b.translatesAutoresizingMaskIntoConstraints = false
            v.addSubview(b)
        }
        v.addSubview(label)
        NSLayoutConstraint.activate([
            label.leftAnchor.constraint(equalTo: v.leftAnchor, constant: 4),
            label.centerYAnchor.constraint(equalTo: v.centerYAnchor),
            pasteBtn.rightAnchor.constraint(equalTo: v.rightAnchor, constant: -2),
            pasteBtn.centerYAnchor.constraint(equalTo: v.centerYAnchor),
            pasteBtn.widthAnchor.constraint(equalToConstant: 54),
            copyBtn.rightAnchor.constraint(equalTo: pasteBtn.leftAnchor, constant: -6),
            copyBtn.centerYAnchor.constraint(equalTo: v.centerYAnchor),
            copyBtn.widthAnchor.constraint(equalToConstant: 44),
            label.rightAnchor.constraint(equalTo: copyBtn.leftAnchor, constant: -8),
            v.heightAnchor.constraint(equalToConstant: 34)
        ])
        return v
    }

    @objc private func clipCopy(_ sender: NSButton) {
        let i = sender.tag
        guard clipRows.indices.contains(i) else { return }
        let pb = NSPasteboard.general
        pb.clearContents(); pb.setString(clipRows[i], forType: .string)
        lastClipCount = pb.changeCount
        respond("COPIED — \(String(clipRows[i].prefix(40)))", .verified)
    }

    @objc private func clipPaste(_ sender: NSButton) {
        let i = sender.tag
        guard clipRows.indices.contains(i) else { return }
        let pb = NSPasteboard.general
        pb.clearContents(); pb.setString(clipRows[i], forType: .string)
        lastClipCount = pb.changeCount
        close()
        previousApp?.activate(options: .activateIgnoringOtherApps)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            agentPressCombo("cmd v")
            State.shared.set(.verified, "PASTED CLIP")
        }
    }

    // MARK: state reflection

    func reflectState(_ s: TriState) {
        stateLabel.stringValue = s.label
        stateLabel.textColor = s == .blocked
            ? NSColor(calibratedRed: 1, green: 0.35, blue: 0.3, alpha: 1)
            : NSColor(calibratedRed: 1, green: 0.55, blue: 0.5, alpha: 0.95)
    }

    func reflectState(_ s: TriState, _ detail: String) {
        reflectState(s)
        stateLabel.stringValue = "\(s.label) — \(detail)"
    }

    func reflectTarget(_ name: String?) {
        guard isOpen else { return }
        if let name = name {
            stateLabel.stringValue = "TARGET — \(name)"
        } else {
            stateLabel.stringValue = TriState.idle.label
        }
    }

    // MARK: input

    func submit() {
        let text = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        field.stringValue = text
        rows = []
        rebuildRows()
        resize(0)
        State.shared.set(.reasoning, "parsing intent")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.route(text)
        }
    }

    func respond(_ detail: String, _ state: TriState) {
        State.shared.set(state, detail)
        field.stringValue = ""
        resize(0)
    }

    // MARK: routing

    private func route(_ text: String) {
        let low = text.lowercased()

        if low.hasPrefix("agent") || low.contains("agent mode") || low.contains("agent drive")
            || low.hasPrefix("do it") || low.contains("by yourself") || low.contains("take over the cursor")
            || low.contains("drive the cursor") || low.contains("control the cursor") {
            runAgent(text); return
        }

        if low == "stop" || low == "record stop" || low.contains("stop recording") {
            isRecording ? stopRecording() : respond("NOTHING TO STOP", .blocked)
            return
        }
        if low == "macros" || low == "list macros" {
            let names = MacroStore.list()
            respond(names.isEmpty ? "NO MACROS SAVED — record <name>" : "MACROS — \(names.joined(separator: ", "))", .verified)
            return
        }
        if low == "record" || low.hasPrefix("record ") {
            startRecording(String(text.dropFirst(6)).trimmingCharacters(in: .whitespaces))
            return
        }
        if low.hasPrefix("replay ") || low.hasPrefix("play ") {
            let first = text.split(separator: " ").first?.count ?? 6
            replayMacro(String(text.dropFirst(first + 1)).trimmingCharacters(in: .whitespaces))
            return
        }
        if low == "clip" || low == "clips" || low.hasPrefix("clip ") || low.contains("clipboard") {
            runClipSearch(text)
            return
        }

        if low.contains("screenshot") || low.contains("screen shot") || low.contains("capture") {
            takeScreenshot(); return
        }

        if low.contains("reveal") || low.contains("show in finder") || low.contains("where is") || low.contains("path of") {
            State.shared.set(.executing, "locating")
            searcher.run(text) { [weak self] rows in
                guard let self = self else { return }
                if let first = rows.first {
                    NSWorkspace.shared.activateFileViewerSelecting([first.url])
                    self.respond("REVEALED — \(first.name)", .verified)
                } else {
                    self.respond("NO MATCH — refine query", .blocked)
                }
            }
            return
        }

        if let (name, url) = matchApp(low), low.contains("open") || low.contains("launch") || low.contains("start") {
            State.shared.set(.executing, "launching \(name)")
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { [weak self] running, err in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if running != nil, err == nil {
                        self.respond("OPENED — \(name)", .verified)
                    } else {
                        self.respond("LAUNCH FAILED — \(err?.localizedDescription ?? "unknown")", .blocked)
                    }
                }
            }
            return
        }

        if low.contains("open in") || low.contains("with ") {
            State.shared.set(.executing, "locating + authoring")
            searcher.run(text) { [weak self] rows in
                guard let self = self, let file = rows.first else {
                    self?.respond("NO MATCH — refine query", .blocked)
                    return
                }
                if let (_, appURL) = self.matchApp(low) {
                    NSWorkspace.shared.open([file.url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration()) { _, err in
                        DispatchQueue.main.async {
                            if err == nil { self.respond("OPENED \(file.name) — VERIFIED", .verified) }
                            else { self.respond("EDITOR FAILED — \(err!.localizedDescription)", .blocked) }
                        }
                    }
                } else {
                    self.openURL(file.url, label: "OPENED — \(file.name)")
                }
            }
            return
        }

        if low.contains("find") || low.contains("search") || low.contains("locate")
            || low.contains("look for") || low.contains("show") || low.contains("get")
            || low.contains("last") || low.contains("latest") || low.contains("yesterday")
            || low.contains("recent") || low.contains("pdf") || low.contains("screenshot")
            || low.contains("file") || low.contains("folder") || low.contains("directory") {
            pendingQuery = text
            State.shared.set(.executing, "searching index")
            searcher.run(text) { [weak self] rows in
                guard let self = self else { return }
                self.rows = rows
                if rows.isEmpty {
                    self.rebuildRows()
                    self.respond("NO MATCH — \(self.pendingQuery)", .blocked)
                } else {
                    self.rebuildRows()
                    self.respond("TARGETS — \(rows.count)", .verified)
                }
            }
            return
        }

        respond("MISSION ENGINE OFFLINE — prototype modes: find <file> · open <app> · reveal <file> · screenshot", .blocked)
    }

    private func openURL(_ url: URL, label: String) {
        let ok = NSWorkspace.shared.open(url)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if ok { self.respond("\(label)", .verified) } else { self.respond("OPEN FAILED", .blocked) }
        }
    }

    // MARK: apps

    private func installedApps() -> [(String, URL)] {
        if let c = appCache { return c }
        var found: [(String, URL)] = []
        let fm = FileManager.default
        let dirs = ["/Applications", "/System/Applications", "/System/Applications/Utilities", NSHomeDirectory() + "/Applications"]
        for d in dirs {
            if let contents = try? fm.contentsOfDirectory(at: URL(fileURLWithPath: d), includingPropertiesForKeys: nil) {
                for u in contents where u.pathExtension == "app" {
                    found.append((u.deletingPathExtension().lastPathComponent, u))
                }
            }
        }
        appCache = found
        return found
    }

    private func matchApp(_ low: String) -> (String, URL)? {
        let noise: Set<String> = ["open", "launch", "start", "the", "app", "application", "my", "a", "an", "please", "in", "with", "it", "new", "window", "project", "vs", "code", "xcode", "edit"]
        let tokens = low.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
            .filter { !noise.contains($0) }
        let phrase = tokens.joined(separator: " ")
        guard !phrase.isEmpty else { return nil }
        var best: (String, URL)? = nil
        for (name, url) in installedApps() {
            let n = name.lowercased()
            if n == phrase || phrase.contains(n) {
                if best == nil || name.count < best!.0.count { best = (name, url) }
            }
        }
        return best
    }

    // MARK: screenshot

    private func desktopURL() -> URL { FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first! }

    private func newestScreenShot() -> (url: URL, date: Date)? {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: desktopURL(), includingPropertiesForKeys: [.contentModificationDateKey]) else { return nil }
        var best: (URL, Date)?
        for u in items {
            let n = u.lastPathComponent.lowercased()
            guard n.contains("screen shot") || n.contains("screenshot") || n.contains("screen capture") || n.hasPrefix("cleanshot") else { continue }
            guard let d = (try? u.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate else { continue }
            if best == nil || d > best!.1 { best = (u, d) }
        }
        guard let b = best else { return nil }
        return (b.0, b.1)
    }

    private func takeScreenshot() {
        State.shared.set(.executing, "select region")
        let before = newestScreenShot()?.date ?? .distantPast
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        proc.arguments = ["-iu"]
        proc.terminationHandler = { @Sendable [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                guard let self = self else { return }
                if let shot = self.newestScreenShot(), shot.date > before {
                    self.rows = [FileRow(name: shot.url.lastPathComponent, url: shot.url, date: shot.date)]
                    self.rebuildRows()
                    self.respond("CAPTURED — \(shot.url.lastPathComponent)", .verified)
                } else {
                    self.respond("CAPTURE CANCELLED", .blocked)
                }
            }
        }
        try? proc.run()
    }

    // MARK: rows

    private func rebuildRows() {
        for v in stack.arrangedSubviews { stack.removeArrangedSubview(v); v.removeFromSuperview() }
        for row in rows { stack.addArrangedSubview(self.makeRow(row)) }
    }

    private func makeRow(_ row: FileRow) -> NSView {
        let v = ResultRow(row: row)
        v.onOpen = { [weak self] in self?.openURL(row.url, label: "OPENED — \(row.name)") }
        v.onReveal = { [weak self] in
            NSWorkspace.shared.activateFileViewerSelecting([row.url])
            self?.respond("REVEALED — \(row.name)", .verified)
        }
        let sep = NSBox()
        sep.boxType = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(sep)
        NSLayoutConstraint.activate([
            sep.leftAnchor.constraint(equalTo: v.leftAnchor),
            sep.rightAnchor.constraint(equalTo: v.rightAnchor),
            sep.bottomAnchor.constraint(equalTo: v.bottomAnchor)
        ])
        return v
    }
}

// MARK: - Result Row

@MainActor
final class ResultRow: NSView {
    var onOpen: (() -> Void)?
    var onReveal: (() -> Void)?
    private let nameLabel = NSTextField(labelWithString: "")
    private let metaLabel = NSTextField(labelWithString: "")
    private let openBtn = NSButton(title: "Open", target: nil, action: nil)
    private let revealBtn = NSButton(title: "Reveal", target: nil, action: nil)

    init(row: FileRow) {
        super.init(frame: NSRect(x: 0, y: 0, width: LensController.width - 24, height: 44))
        wantsLayer = true
        nameLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        nameLabel.textColor = .white
        nameLabel.lineBreakMode = .byTruncatingMiddle
        metaLabel.font = .monospacedSystemFont(ofSize: 8.5, weight: .regular)
        metaLabel.textColor = NSColor(white: 0.55, alpha: 1)
        metaLabel.lineBreakMode = .byTruncatingMiddle

        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        nameLabel.stringValue = row.name
        metaLabel.stringValue = "\(df.string(from: row.date ?? Date())) · \(row.url.deletingLastPathComponent().path)"

        for b in [openBtn, revealBtn] {
            b.font = .monospacedSystemFont(ofSize: 9, weight: .bold)
            b.isBordered = false
            b.wantsLayer = true
            b.layer?.cornerRadius = 4
            b.layer?.borderWidth = 1
            b.layer?.borderColor = NSColor(calibratedRed: 1, green: 0.3, blue: 0.25, alpha: 0.7).cgColor
            b.contentTintColor = NSColor(calibratedRed: 1, green: 0.5, blue: 0.45, alpha: 1)
        }
        openBtn.target = self; openBtn.action = #selector(doOpen)
        revealBtn.target = self; revealBtn.action = #selector(doReveal)

        addSubview(nameLabel); addSubview(metaLabel); addSubview(openBtn); addSubview(revealBtn)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        openBtn.translatesAutoresizingMaskIntoConstraints = false
        revealBtn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            nameLabel.leftAnchor.constraint(equalTo: leftAnchor, constant: 4),
            nameLabel.rightAnchor.constraint(equalTo: openBtn.leftAnchor, constant: -8),
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            metaLabel.leftAnchor.constraint(equalTo: leftAnchor, constant: 4),
            metaLabel.rightAnchor.constraint(equalTo: nameLabel.rightAnchor),
            metaLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 1),
            openBtn.rightAnchor.constraint(equalTo: revealBtn.leftAnchor, constant: -6),
            openBtn.centerYAnchor.constraint(equalTo: centerYAnchor),
            openBtn.widthAnchor.constraint(equalToConstant: 44),
            revealBtn.rightAnchor.constraint(equalTo: rightAnchor, constant: -2),
            revealBtn.centerYAnchor.constraint(equalTo: centerYAnchor),
            revealBtn.widthAnchor.constraint(equalToConstant: 52),
            heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    @objc private func doOpen() { onOpen?() }
    @objc private func doReveal() { onReveal?() }
}

// MARK: - Global Hotkey (Carbon)

private func hotkeyHandler(nextHandler: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    var id = EventHotKeyID()
    GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
    let hid = id.id
    DispatchQueue.main.async {
        switch hid {
        case 1, 3, 4, 5: State.shared.lens?.toggle()
        case 2: State.shared.lens?.close()
        default: break
        }
    }
    return noErr
}

private func installHotKeys() {
    var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    var handlerRef: EventHandlerRef?
    InstallEventHandler(GetApplicationEventTarget(), hotkeyHandler, 1, &spec, nil, &handlerRef)

    let sig = OSType(0x4E585452)
    func reg(_ code: UInt32, _ mods: UInt32, _ id: UInt32) {
        var ref: EventHotKeyRef?
        let err = RegisterEventHotKey(code, mods, EventHotKeyID(signature: sig, id: id), GetApplicationEventTarget(), 0, &ref)
        LoginItem.log("hotkey id=\(id) code=\(code) mods=\(mods) -> \(err)")
    }
    reg(UInt32(kVK_Space), UInt32(optionKey), 1)     // ⌥Space
    reg(UInt32(kVK_Escape), 0, 2)                    // Escape dismisses
    reg(UInt32(kVK_Control), UInt32(controlKey), 3)  // ⌃⌃ (backup; modifier keys emit flagsChanged)
    reg(UInt32(kVK_Command), UInt32(cmdKey), 4)      // ⌘⌘ (backup)
    reg(UInt32(kVK_Space), UInt32(controlKey | optionKey), 5)  // ⌃⌥Space — no permissions needed
}

private func installGlobalMonitor() {
    guard AXIsProcessTrusted() else {
        LoginItem.log("global monitor skipped — Accessibility not trusted")
        return
    }
    NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
        guard event.keyCode == UInt16(kVK_Control) else { return }
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard mods.contains(.control), !mods.contains(.command), !mods.contains(.option), !mods.contains(.shift) else { return }
        let now = Date()
        if now.timeIntervalSince(GlobalCtrl.last) < 0.4 {
            GlobalCtrl.last = .distantPast
            DispatchQueue.main.async { State.shared.lens?.toggle() }
        } else {
            GlobalCtrl.last = now
        }
    }
}

private enum GlobalCtrl { static var last: Date = .distantPast }

// MARK: - Launch at Login

enum LoginItem {
    static var mainAppPlist: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("LaunchAgents/com.nexus.triangle.plist")
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled || FileManager.default.fileExists(atPath: mainAppPlist.path)
    }

    static func log(_ msg: String) {
        let url = URL(fileURLWithPath: "/tmp/nexus-triangle.log")
        let line = "\(Date()): \(msg)\n"
        if let data = line.data(using: .utf8) {
            if let h = try? FileHandle(forWritingTo: url) {
                h.seekToEndOfFile()
                h.write(data)
                try? h.close()
            } else {
                try? data.write(to: url)
            }
        }
    }

    static func enable() throws {
        try? SMAppService.mainApp.register()
        if SMAppService.mainApp.status == .enabled { return }
        // ad-hoc builds may require user approval — guarantee boot start with a LaunchAgent
        let bundle = Bundle.main.bundlePath
        let plist: [String: Any] = [
            "Label": "com.nexus.triangle",
            "ProgramArguments": [bundle + "/Contents/MacOS/NexusTriangle"],
            "RunAtLoad": true,
            "KeepAlive": false,
            "StandardOutPath": "/tmp/nexus-triangle.log",
            "StandardErrorPath": "/tmp/nexus-triangle.log"
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let dir = mainAppPlist.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: mainAppPlist)
    }

    static func disable() {
        if SMAppService.mainApp.status == .enabled {
            try? SMAppService.mainApp.unregister()
        }
        try? FileManager.default.removeItem(at: mainAppPlist)
    }
}

// MARK: - App Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var overlay: OverlayController!
    private var lens: LensController!
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        overlay = OverlayController()
        overlay.start()
        lens = LensController()
        installHotKeys()
        installGlobalMonitor()
        buildStatusBar()
        pickModel()
        // starts with the triangle every boot
        if !LoginItem.isEnabled {
            do {
                try LoginItem.enable()
                LoginItem.log("enabled, status=\(SMAppService.mainApp.status.rawValue), plistExists=\(FileManager.default.fileExists(atPath: LoginItem.mainAppPlist.path))")
            } catch {
                LoginItem.log("enable failed: \(error)")
                lens.respond("LOGIN ENABLE FAILED — \(error.localizedDescription)", .blocked)
            }
        }
    }

    private func buildStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }

        let img = NSImage(size: NSSize(width: 20, height: 20), flipped: false) { rect in
            let p = NSBezierPath()
            let cy = rect.midY
            p.move(to: NSPoint(x: rect.midX, y: cy + 8))
            p.line(to: NSPoint(x: rect.midX - 8, y: cy - 6))
            p.line(to: NSPoint(x: rect.midX + 8, y: cy - 6))
            p.close()
            NSColor(calibratedRed: 1, green: 0.2, blue: 0.18, alpha: 1).setFill()
            p.fill()
            return true
        }
        img.isTemplate = false
        button.image = img
        button.title = ""
        button.toolTip = "Nexus Triangle"

        let menu = NSMenu()
        menu.addItem(withTitle: "Nexus Triangle", action: nil, keyEquivalent: "")
        let lensItem = menu.addItem(withTitle: "Command Lens  (⌃⌃ / ⌥Space / ⌃⌥Space)", action: #selector(lensOpen), keyEquivalent: "")
        lensItem.target = self
        let closeItem = menu.addItem(withTitle: "Close Lens", action: #selector(lensClose), keyEquivalent: "")
        closeItem.target = self
        let pinItem = menu.addItem(withTitle: "Pin / Unpin Lens  (⌘P)", action: #selector(lensPin), keyEquivalent: "")
        pinItem.target = self
        let triItem = menu.addItem(withTitle: "Hide Triangle", action: #selector(toggleTri), keyEquivalent: "")
        triItem.target = self
        menu.addItem(.separator())
        let login = menu.addItem(withTitle: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        refreshLoginState(login)
        let axItem = menu.addItem(withTitle: "Grant Accessibility…", action: #selector(grantAX), keyEquivalent: "")
        axItem.target = self
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "Quit Triangle", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = self
        statusItem.menu = menu
    }

    @objc private func lensOpen() { lens.toggle() }
    @objc private func lensClose() { lens.close() }
    @objc private func lensPin() {
        if !lens.isOpen { lens.open() }
        lens.togglePin()
    }
    private func pickModel() {
        guard let url = URL(string: "http://localhost:11434/api/tags") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let d = data,
                  let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                  let models = j["models"] as? [[String: Any]] else { return }
            let names = models.compactMap { $0["name"] as? String }
            guard let best = names.first(where: { $0.contains("3b") }) ?? names.first else { return }
            DispatchQueue.main.async { agentModel = best; LoginItem.log("agent model: \(best)") }
        }.resume()
    }
    @objc private func toggleTri() {
        State.shared.on.toggle()
        statusItem.menu?.item(at: 2)?.title = State.shared.on ? "Hide Triangle" : "Show Triangle"
    }
    @objc private func toggleLogin(_ sender: NSMenuItem) {
        if LoginItem.isEnabled {
            LoginItem.disable()
        } else {
            do {
                try LoginItem.enable()
            } catch {
                lens.respond("LOGIN TOGGLE FAILED — \(error.localizedDescription)", .blocked)
            }
        }
        refreshLoginState(sender)
    }

    private func refreshLoginState(_ item: NSMenuItem) {
        item.state = LoginItem.isEnabled ? .on : .off
    }

    @MainActor @objc private func grantAX() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts = [promptKey: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
        installGlobalMonitor()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Agent Engine (Ollama drives the cursor)

@MainActor var agentModel = "llama3.2:3b"
@MainActor var agentBusy = false
@MainActor private var agentCancelled = false
private var agentHistory: [[String: Any]] = []
private var agentSteps: [String] = []
private var agentCursor: CGPoint = .zero
@MainActor private var agentNudges = 0

// MARK: - Macro (record & replay)

struct MacroEvent: Codable {
    let t: Double
    let type: String
    var x: Double = 0
    var y: Double = 0
    var keyCode: Int64 = 0
    var flags: UInt64 = 0
    var text: String = ""
}

struct Macro: Codable {
    let name: String
    let events: [MacroEvent]
}

enum MacroStore {
    static var dir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Nexus/macros", isDirectory: true)
    }
    static func safe(_ name: String) -> String {
        name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ".", with: "-")
    }
    static func file(_ name: String) -> URL { dir.appendingPathComponent("\(safe(name)).json") }
    static func list() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "json" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }
    static func save(_ m: Macro) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? JSONEncoder().encode(m).write(to: file(m.name))
    }
    static func load(_ name: String) -> Macro? {
        guard let d = try? Data(contentsOf: file(name)) else { return nil }
        return try? JSONDecoder().decode(Macro.self, from: d)
    }
}

private func macroTapCB(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                        refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard MacroTap.recording else { return Unmanaged.passUnretained(event) }
    let t = Double(DispatchTime.now().uptimeNanoseconds - MacroTap.t0.uptimeNanoseconds) / 1_000_000
    switch type {
    case .mouseMoved:
        let p = event.location
        let moved = hypot(p.x - MacroTap.lastPos.x, p.y - MacroTap.lastPos.y) > 3
        if moved || t - MacroTap.lastT > 150 {
            MacroTap.buffer.append(MacroEvent(t: t, type: "move", x: p.x, y: p.y))
            MacroTap.lastPos = p
            MacroTap.lastT = t
        }
    case .leftMouseDown:
        let p = event.location
        MacroTap.buffer.append(MacroEvent(t: t, type: "md", x: p.x, y: p.y))
    case .leftMouseUp:
        let p = event.location
        MacroTap.buffer.append(MacroEvent(t: t, type: "mu", x: p.x, y: p.y))
    case .keyDown:
        var units = [UniChar](repeating: 0, count: 8)
        var len = 0
        event.keyboardGetUnicodeString(maxStringLength: 8, actualStringLength: &len, unicodeString: &units)
        let s = String(utf16CodeUnits: units, count: len)
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        MacroTap.buffer.append(MacroEvent(t: t, type: "key", keyCode: code, flags: event.flags.rawValue, text: s))
    default: break
    }
    if MacroTap.buffer.count > 4000 { MacroTap.recording = false }
    return Unmanaged.passUnretained(event)
}

enum MacroTap {
    static var buffer: [MacroEvent] = []
    static var recording = false
    static var t0 = DispatchTime.now()
    static var tap: CFMachPort?
    static var lastPos: CGPoint = .zero
    static var lastT: Double = 0

    static func start() -> Bool {
        buffer = []
        lastPos = .zero
        lastT = 0
        t0 = .now()
        let mask: CGEventMask =
            (1 << CGEventType.mouseMoved.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.leftMouseUp.rawValue)
            | (1 << CGEventType.keyDown.rawValue)
        let cb: CGEventTapCallBack = macroTapCB
        guard let t = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap,
                                         options: .listenOnly, eventsOfInterest: mask,
                                         callback: cb, userInfo: nil) else { return false }
        tap = t
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        recording = true
        return true
    }

    static func stop() -> [MacroEvent] {
        recording = false
        if let t = tap {
            CGEvent.tapEnable(tap: t, enable: false)
            CFMachPortInvalidate(t)
            tap = nil
        }
        return buffer
    }
}

private let agentTools: [[String: Any]] = [
    ["type": "function", "function": [
        "name": "move",
        "description": "Move the AI cursor to a screen point. x grows right, y grows down from the TOP-LEFT corner of the main display.",
        "parameters": ["type": "object",
                       "properties": ["x": ["type": "number"], "y": ["type": "number"]],
                       "required": ["x", "y"]]
    ]],
    ["type": "function", "function": [
        "name": "click",
        "description": "Click at the current AI cursor position.",
        "parameters": ["type": "object",
                       "properties": ["button": ["type": "string", "enum": ["left", "right"]],
                                      "count": ["type": "number", "enum": [1, 2]]],
                       "required": []]
    ]],
    ["type": "function", "function": [
        "name": "type_text",
        "description": "Type a string of text at the current focus point.",
        "parameters": ["type": "object",
                       "properties": ["text": ["type": "string"]],
                       "required": ["text"]]
    ]],
    ["type": "function", "function": [
        "name": "key",
        "description": "Press a key combination, e.g. 'return', 'escape', 'cmd space', 'cmd t', 'tab'.",
        "parameters": ["type": "object",
                       "properties": ["combo": ["type": "string"]],
                       "required": ["combo"]]
    ]],
    ["type": "function", "function": [
        "name": "scroll",
        "description": "Scroll the view at the current cursor position.",
        "parameters": ["type": "object",
                       "properties": ["dx": ["type": "number"], "dy": ["type": "number"]],
                       "required": []]
    ]],
    ["type": "function", "function": [
        "name": "look",
        "description": "Inspect the UI element under the current AI cursor. Returns role/title or 'unknown element'.",
        "parameters": ["type": "object", "properties": [:], "required": []]
    ]],
    ["type": "function", "function": [
        "name": "done",
        "description": "Call when the task is complete. Give a one-line verified summary.",
        "parameters": ["type": "object",
                       "properties": ["summary": ["type": "string"]],
                       "required": ["summary"]]
    ]]
]

private func agentSystemPrompt() -> String {
    let s = NSScreen.main?.frame.size ?? NSSize(width: 1440, height: 900)
    return """
    You are NEXUS, a red-triangle macOS agent. You control the computer cursor directly through tools.
    Screen: \(Int(s.width)) x \(Int(s.height)), origin top-left.

    Rules:
    - Call exactly ONE tool at a time. After each call you receive the result.
    - The cursor starts at screen center. Use look() when uncertain what is under the cursor.
    - Prefer keyboard shortcuts over mouse hunting when a shortcut exists.
    - Never ask questions. Act. If blocked after 3 attempts, call done() describing the failure honestly.
    - Call done(summary) when finished. Keep summaries under 80 characters.
    """
}

@MainActor private func askOllama(_ done: @escaping ([String: Any]?, Error?) -> Void) {
    guard let url = URL(string: "http://localhost:11434/api/chat") else { done(nil, nil); return }
    let body: [String: Any] = [
        "model": agentModel,
        "messages": agentHistory,
        "tools": agentTools,
        "stream": false,
        "options": ["temperature": 0.2, "num_predict": 200]
    ]
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.timeoutInterval = 120
    req.httpBody = try? JSONSerialization.data(withJSONObject: body)
    URLSession.shared.dataTask(with: req) { data, _, err in
        var json: [String: Any]?
        if let d = data, let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] { json = j }
        DispatchQueue.main.async { done(json, err) }
    }.resume()
}

// MARK: synthetic input (requires Accessibility)

private let kCGModifiers: [(String, CGKeyCode)] = [
    ("cmd", 55), ("command", 55), ("⌘", 55),
    ("alt", 58), ("option", 58), ("⌥", 58), ("opt", 58),
    ("ctrl", 59), ("control", 59), ("⌃", 59),
    ("shift", 56), ("⇧", 56), ("fn", 63)
]

private let kCGKeys: [(String, CGKeyCode)] = [
    ("return", 36), ("enter", 36), ("⏎", 36), ("tab", 48), ("space", 49),
    ("delete", 51), ("backspace", 51), ("esc", 53), ("escape", 53),
    ("left", 123), ("right", 124), ("down", 125), ("up", 126),
    ("f1", 122), ("f2", 120), ("f3", 99), ("f4", 118), ("f5", 96), ("f11", 103),
    ("home", 115), ("end", 119), ("pageup", 116), ("pagedown", 121),
    ("a", 0), ("b", 11), ("c", 8), ("d", 2), ("e", 14), ("f", 3), ("g", 5),
    ("h", 4), ("i", 34), ("j", 38), ("k", 40), ("l", 37), ("m", 46), ("n", 45),
    ("o", 31), ("p", 35), ("q", 12), ("r", 15), ("s", 1), ("t", 17), ("u", 32),
    ("v", 9), ("w", 13), ("x", 7), ("y", 16), ("z", 6),
    ("0", 29), ("1", 18), ("2", 19), ("3", 20), ("4", 21), ("5", 23),
    ("6", 22), ("7", 26), ("8", 28), ("9", 25),
    ("-", 27), ("=", 24), (",", 43), (".", 47), ("/", 44)
]

@MainActor private let agentDryRun = ProcessInfo.processInfo.environment["NEXUS_DRY"] == "1"

private func agentPostSource() -> CGEventSource? { CGEventSource(stateID: CGEventSourceStateID(rawValue: 1)!) }

@MainActor private func agentMoveMouse(to p: CGPoint) {
    agentCursor = p
    if agentDryRun { State.shared.overlay?.execTarget = p; return }
    let ev = CGEvent(mouseEventSource: agentPostSource(), mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left)
    ev?.post(tap: .cghidEventTap)
    State.shared.overlay?.execTarget = p
}

@MainActor private func agentClick(_ button: CGMouseButton, count: Int) {
    agentMoveMouse(to: agentCursor)
    if agentDryRun { return }
    let down: CGEventType, up: CGEventType
    switch button {
    case .right: down = .rightMouseDown; up = .rightMouseUp
    default: down = .leftMouseDown; up = .leftMouseUp
    }
    for i in 0..<count {
        if let e = CGEvent(mouseEventSource: agentPostSource(), mouseType: down, mouseCursorPosition: agentCursor, mouseButton: button) {
            e.setIntegerValueField(.mouseEventClickState, value: Int64(i + 1))
            e.post(tap: .cghidEventTap)
        }
        if let e = CGEvent(mouseEventSource: agentPostSource(), mouseType: up, mouseCursorPosition: agentCursor, mouseButton: button) {
            e.setIntegerValueField(.mouseEventClickState, value: Int64(i + 1))
            e.post(tap: .cghidEventTap)
        }
        usleep(60000)
    }
}

private func agentType(_ text: String) {
    if agentDryRun { return }
    let units = Array(text.utf16)
    for (i, _) in units.enumerated() {
        let src = agentPostSource()
        for kd: Bool in [true, false] {
            if let e = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: kd) {
                units.withUnsafeBufferPointer { buf in
                    e.keyboardSetUnicodeString(stringLength: units.count - i, unicodeString: buf.baseAddress!.advanced(by: i))
                }
                e.post(tap: .cghidEventTap)
            }
        }
        usleep(15000)
    }
}

private func agentPressCombo(_ combo: String) {
    let tokens = combo.lowercased()
        .split(whereSeparator: { $0 == "+" || $0 == " " })
        .map(String.init)
        .filter { !$0.isEmpty }
    guard !tokens.isEmpty else { return }
    if agentDryRun { return }
    var mods: [CGKeyCode] = []
    var key: CGKeyCode?
    for t in tokens {
        if let m = kCGModifiers.first(where: { $0.0 == t })?.1 { mods.append(m); continue }
        if let k = kCGKeys.first(where: { $0.0 == t })?.1 { key = k; continue }
        if let scalar = t.unicodeScalars.first, let k = agentKeycodeFor(scalar) { key = k; continue }
    }
    var flags = CGEventFlags()
    for m in mods {
        let f: CGEventFlags = (m == 55) ? .maskCommand : (m == 58) ? .maskAlternate : (m == 59) ? .maskControl : .maskShift
        flags.insert(f)
    }
    let src = agentPostSource()
    for m in mods {
        if let e = CGEvent(keyboardEventSource: src, virtualKey: m, keyDown: true) {
            e.flags = flags
            e.post(tap: .cghidEventTap)
        }
    }
    if let k = key {
        if let e = CGEvent(keyboardEventSource: src, virtualKey: k, keyDown: true) { e.flags = flags; e.post(tap: .cghidEventTap) }
        usleep(30000)
        if let e = CGEvent(keyboardEventSource: src, virtualKey: k, keyDown: false) { e.flags = flags; e.post(tap: .cghidEventTap) }
    }
    for m in mods.reversed() {
        if let e = CGEvent(keyboardEventSource: src, virtualKey: m, keyDown: false) { e.flags = []; e.post(tap: .cghidEventTap) }
    }
}

private func agentKeycodeFor(_ s: Unicode.Scalar) -> CGKeyCode? {
    guard let c = Character(s).lowercased().first else { return nil }
    return kCGKeys.first { String($0.0) == String(c) }?.1
}

private func agentScroll(dx: Int, dy: Int) {
    if agentDryRun { return }
    if let e = CGEvent(scrollWheelEvent2Source: agentPostSource(), units: .pixel, wheelCount: 2, wheel1: Int32(dy), wheel2: Int32(dx), wheel3: 0) {
        e.post(tap: .cghidEventTap)
    }
}

// MARK: - Lens agent extension

@MainActor
extension LensController {

    func runAgent(_ task: String) {
        guard AXIsProcessTrusted() || agentDryRun else {
            respond("PERMISSION REQUIRED — activate Accessibility (menu bar ▸ Grant Accessibility…)", .blocked)
            return
        }
        if agentBusy {
            respond("AGENT BUSY — esc to abort current mission", .blocked)
            return
        }
        let s = NSScreen.main?.frame.size ?? NSSize(width: 1440, height: 900)
        agentCursor = CGPoint(x: s.width / 2, y: s.height / 2)
        agentMoveMouse(to: agentCursor)
        agentSteps = ["TASK · \(task)"]
        agentNudges = 0
        agentBusy = true
        agentCancelled = false
        State.shared.overlay?.agentActive = true
        State.shared.set(.reasoning, "agent engaging · \(agentModel)")
        rebuildSteps()
        resize(agentSteps.count)
        agentHistory = [
            ["role": "system", "content": agentSystemPrompt()],
            ["role": "user", "content": task]
        ]
        agentTurn()
    }

    private func agentTurn() {
        guard !agentCancelled else { return }
        if agentHistory.count >= 26 {
            agentFail("STEP LIMIT REACHED (12 tool calls) — refine the task")
            return
        }
        State.shared.set(.reasoning, "agent thinking · step \(agentHistory.count / 2)")
        askOllama { [weak self] json, err in
            guard let self = self, !agentCancelled else { return }
            guard let json = json, let msg = json["message"] as? [String: Any] else {
                let e = err?.localizedDescription ?? (json?["error"] as? String) ?? "no response"
                self.agentFail("OLLAMA — \(e)")
                return
            }
            // remember assistant turn
            agentHistory.append(["role": "assistant", "content": msg["content"] as? String ?? "", "tool_calls": msg["tool_calls"] as? [[String: Any]] ?? []])

            var name: String?
            var args: [String: Any] = [:]
            if let calls = msg["tool_calls"] as? [[String: Any]], let first = calls.first,
               let fn = first["function"] as? [String: Any], let n = fn["name"] as? String {
                name = n
                if let a = fn["arguments"] as? [String: Any] { args = a }
                else if let a = fn["arguments"] as? String, let d = a.data(using: .utf8),
                        let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] { args = j }
            } else if let text = msg["content"] as? String, let parsed = Self.extractJSON(text) {
                name = parsed["tool"] as? String ?? parsed["action"] as? String ?? parsed["name"] as? String
                args = parsed
            }

            guard let tool = name else {
                // salvage: model answered with plain text — try deterministic action
                if let text = msg["content"] as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if let (n, url) = matchApp(text) {
                        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                        self.agentFinish("opened \(n) — deterministic fallback")
                        return
                    }
                    if agentNudges < 2 {
                        agentNudges += 1
                        agentHistory.append(["role": "system", "content": "Call exactly one tool from the provided list. Never answer with plain text. Tools: move, click, type_text, key, scroll, look, done."])
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.agentTurn() }
                        return
                    }
                }
                self.agentFail("MODEL RETURNED NO TOOL — \(agentModel) may be too small; try llama3.2:3b")
                return
            }
            agentNudges = 0
            self.agentExecute(tool, args)
        }
    }


    private func agentExecute(_ tool: String, _ args: [String: Any]) {
        let result: String
        switch tool {
        case "move":
            let x = Self.num(args["x"]), y = Self.num(args["y"])
            agentMoveMouse(to: CGPoint(x: x, y: y))
            result = "cursor → \(Int(x)),\(Int(y))"
        case "click":
            let button: CGMouseButton = (args["button"] as? String) == "right" ? .right : .left
            let count = Self.int(args["count"], 1)
            agentClick(button, count: count)
            result = "clicked \(button == .right ? "right" : "left") x\(count) at \(Int(agentCursor.x)),\(Int(agentCursor.y))"
        case "type_text":
            let text = args["text"] as? String ?? ""
            agentType(text)
            result = "typed \(text.count) chars"
        case "key":
            let combo = args["combo"] as? String ?? ""
            agentPressCombo(combo)
            result = "key '\(combo)'"
        case "scroll":
            let dx = Self.int(args["dx"], 0), dy = Self.int(args["dy"], -300)
            agentScroll(dx: dx, dy: dy)
            result = "scroll \(dx),\(dy)"
        case "look":
            var elRef: AXUIElement?
            let system = AXUIElementCreateSystemWide()
            let aerr = AXUIElementCopyElementAtPosition(system, Float(agentCursor.x), Float(agentCursor.y), &elRef)
            if aerr == .success, let el = elRef {
                var t: AnyObject?
                AXUIElementCopyAttributeValue(el, kAXTitleAttribute as CFString, &t)
                var r: AnyObject?
                AXUIElementCopyAttributeValue(el, kAXRoleDescriptionAttribute as CFString, &r)
                result = "element: \(r as? String ?? "?") '\(t as? String ?? "")'"
            } else {
                result = "unknown element"
            }
        case "done":
            let summary = args["summary"] as? String ?? "complete"
            self.agentFinish(summary)
            return
        default:
            let lname = tool.lowercased()
            if ["open", "launch", "app", "openapp", "reveal"].contains(lname) {
                let app = (args["app"] as? String) ?? (args["name"] as? String) ?? (args["app_name"] as? String) ?? ""
                var hit = matchApp("open \(app)")
                if hit == nil, !args.isEmpty { hit = matchApp(String(describing: args)) }
                if let (n, url) = hit {
                    NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                    result = "sent launch to \(n)"
                } else {
                    result = "no app matching '\(app)'"
                }
            } else if ["find", "search", "locate", "open_file", "file"].contains(lname) {
                let q = (args["query"] as? String) ?? (args["q"] as? String) ?? (args["name"] as? String) ?? ""
                State.shared.set(.executing, "index search")
                agentSteps.append("search → '\(q)'")
                trimSteps()
                rebuildSteps()
                searcher.run(q) { rows in
                    let names = rows.prefix(5).map { $0.name }.joined(separator: ", ")
                    agentHistory.append(["role": "tool", "content": "\(rows.count) results: \(names)"])
                    agentSteps.append("search → \(rows.count) results")
                    self.trimSteps()
                    self.rebuildSteps()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in self?.agentTurn() }
                }
                return
            } else {
                result = "unknown tool '\(tool)' — valid: move, click, type_text, key, scroll, look, done"
            }
        }
        State.shared.set(.executing, tool)
        agentSteps.append("\(tool) → \(result)")
        trimSteps()
        rebuildSteps()
        agentHistory.append(["role": "tool", "content": result])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.agentTurn()
        }
    }

    private func trimSteps() {
        if agentSteps.count > 8 { agentSteps.removeFirst(agentSteps.count - 8) }
    }

    private func agentFail(_ detail: String) {
        agentBusy = false
        agentCancelled = true
        State.shared.overlay?.agentActive = false
        agentSteps.append("✖ \(detail)")
        trimSteps()
        rebuildSteps()
        respond("BLOCKED — \(detail)", .blocked)
    }

    fileprivate func agentFinish(_ summary: String) {
        agentBusy = false
        agentCancelled = false
        State.shared.overlay?.agentActive = false
        State.shared.overlay?.execTarget = nil
        agentSteps.append("✓ \(summary)")
        trimSteps()
        rebuildSteps()
        respond("AGENT VERIFIED — \(summary)", .verified)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { State.shared.set(.idle) }
    }

    private func rebuildSteps() {
        for v in stack.arrangedSubviews { stack.removeArrangedSubview(v); v.removeFromSuperview() }
        for step in agentSteps { stack.addArrangedSubview(stepRow(step)) }
    }

    private func stepRow(_ text: String) -> NSView {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: Self.width - 24, height: 22))
        let label = NSTextField(labelWithString: text)
        label.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        label.textColor = text.hasPrefix("✖") ? NSColor(calibratedRed: 1, green: 0.35, blue: 0.3, alpha: 1)
            : text.hasPrefix("✓") ? .white
            : NSColor(white: 0.75, alpha: 1)
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(label)
        NSLayoutConstraint.activate([
            label.leftAnchor.constraint(equalTo: v.leftAnchor, constant: 4),
            label.rightAnchor.constraint(equalTo: v.rightAnchor),
            label.centerYAnchor.constraint(equalTo: v.centerYAnchor),
            v.heightAnchor.constraint(equalToConstant: 22)
        ])
        return v
    }

    fileprivate static func num(_ v: Any?) -> CGFloat {
        if let d = v as? Double { return CGFloat(d) }
        if let i = v as? Int { return CGFloat(i) }
        if let s = v as? String { return CGFloat(Double(s) ?? 0) }
        return 0
    }

    fileprivate static func int(_ v: Any?, _ def: Int) -> Int {
        if let i = v as? Int { return i }
        if let d = v as? Double { return Int(d) }
        if let s = v as? String { return Int(s) ?? def }
        return def
    }

    fileprivate static func extractJSON(_ text: String) -> [String: Any]? {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            t = t.replacingOccurrences(of: "```json", with: "")
            t = t.replacingOccurrences(of: "```", with: "")
        }
        guard let d = t.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: d) as? [String: Any]
    }

    func agentAbort() {
        agentCancelled = true
        agentBusy = false
        State.shared.overlay?.agentActive = false
        State.shared.overlay?.execTarget = nil
    }
}

// MARK: - Entry

let app = NSApplication.shared
MainActor.assumeIsolated {
    app.delegate = AppDelegate()
    app.setActivationPolicy(.accessory)
    app.run()
}