import Cocoa

struct Project: Codable {
    var id: String
    var name: String
    var progress: String?
    var owner: String?
    var lastFollowedAt: Date?
    var isArchived: Bool?
    var status: String? = nil
    var subgroup: String? = nil
}

struct ProjectGroup: Codable {
    var id: String
    var name: String
    var projects: [Project]
    var subgroups: [String]? = nil
    var isArchived: Bool? = nil
}

struct ProjectStore: Codable {
    var version: Int
    var groups: [ProjectGroup]
}

final class EditableCell: NSTextField {
    var onCommit: ((String) -> Void)?

    override func resignFirstResponder() -> Bool {
        onCommit?(stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        return super.resignFirstResponder()
    }
}

final class FlippedStackView: NSStackView {
    override var isFlipped: Bool { true }
}

final class AuroraBackgroundView: NSView {
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let base = NSBezierPath(rect: bounds)
        NSGraphicsContext.saveGraphicsState()
        base.addClip()
        NSGradient(colors: [
            NSColor(calibratedWhite: 1, alpha: 0.98),
            NSColor(calibratedRed: 0.97, green: 0.98, blue: 1, alpha: 0.97),
            NSColor(calibratedRed: 1, green: 0.97, blue: 0.985, alpha: 0.96)
        ])?.draw(in: bounds, angle: -18)

        let blobs: [(NSColor, NSRect)] = [
            (NSColor.systemCyan.withAlphaComponent(0.17), NSRect(x: -80, y: -65, width: 390, height: 245)),
            (NSColor.systemPink.withAlphaComponent(0.12), NSRect(x: bounds.midX - 170, y: -105, width: 410, height: 260)),
            (NSColor.systemYellow.withAlphaComponent(0.14), NSRect(x: bounds.maxX - 300, y: -45, width: 360, height: 230)),
            (NSColor.systemGreen.withAlphaComponent(0.11), NSRect(x: bounds.maxX - 430, y: bounds.maxY - 230, width: 330, height: 210)),
            (NSColor.systemPurple.withAlphaComponent(0.09), NSRect(x: 60, y: bounds.maxY - 220, width: 360, height: 230))
        ]
        for (color, rect) in blobs {
            NSGradient(colors: [color, color.withAlphaComponent(0)])?.draw(in: NSBezierPath(ovalIn: rect), relativeCenterPosition: .zero)
        }
        NSGraphicsContext.restoreGraphicsState()
    }
}

final class ClosureButton: NSButton {
    var handler: (() -> Void)?

    convenience init(title: String, handler: @escaping () -> Void) {
        self.init(title: title, target: nil, action: #selector(runHandler))
        self.target = self
        self.handler = handler
        self.isBordered = false
    }

    @objc private func runHandler() { handler?() }
}

final class ProjectDragHandle: NSView {
    var onReorder: ((Int) -> Void)?
    private var isTrackingDrag = false

    override var intrinsicContentSize: NSSize { NSSize(width: 22, height: 28) }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let text = "⠿" as NSString
        text.draw(at: NSPoint(x: 3, y: 5), withAttributes: [
            .font: NSFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: NSColor.tertiaryLabelColor
        ])
    }

    override func mouseDown(with event: NSEvent) {
        guard !isTrackingDrag, let window else { return }
        isTrackingDrag = true
        let startY = event.locationInWindow.y
        var lastY = startY
        while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp], until: .distantFuture, inMode: .eventTracking, dequeue: true) {
            lastY = next.locationInWindow.y
            if next.type == .leftMouseUp { break }
        }
        isTrackingDrag = false
        let rowOffset = Int(round((startY - lastY) / 46.0))
        if rowOffset != 0 { onReorder?(rowOffset) }
    }
}

struct CountdownTimes {
    var start: Int
    var end: Int
    static let fallback = CountdownTimes(start: 9 * 60, end: 18 * 60)
    static func text(_ minutes: Int) -> String { String(format: "%02d:%02d", minutes / 60, minutes % 60) }
    static func parse(_ value: String) -> Int? {
        let parts = value.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]), (0...23).contains(h), (0...59).contains(m) else { return nil }
        return h * 60 + m
    }
}

final class CompactCountdownView: NSView {
    weak var owner: AppDelegate?
    var tick: CGFloat = 0
    var pomodoroEnd: Date?
    var pomodoroTotal: TimeInterval = 25 * 60
    var times: CountdownTimes {
        didSet {
            UserDefaults.standard.set(times.start, forKey: "offworkCountdown.startMinutes")
            UserDefaults.standard.set(times.end, forKey: "offworkCountdown.endMinutes")
        }
    }

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        let defaults = UserDefaults.standard
        times = CountdownTimes(
            start: defaults.object(forKey: "offworkCountdown.startMinutes") as? Int ?? CountdownTimes.fallback.start,
            end: defaults.object(forKey: "offworkCountdown.endMinutes") as? Int ?? CountdownTimes.fallback.end
        )
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func rightMouseDown(with event: NSEvent) { owner?.showCompactMenu(event, view: self) }

    func startPomodoro(minutes: Int) {
        pomodoroTotal = TimeInterval(minutes * 60)
        pomodoroEnd = Date().addingTimeInterval(pomodoroTotal)
        owner?.syncCompactSize(animated: true)
        needsDisplay = true
    }

    func stopPomodoro() {
        pomodoroEnd = nil
        owner?.syncCompactSize(animated: true)
        needsDisplay = true
    }

    var hasActivePomodoro: Bool { (pomodoroEnd?.timeIntervalSinceNow ?? 0) > 0 }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill(); dirtyRect.fill()
        let panel = bounds.insetBy(dx: 10, dy: 10)
        let shadow = NSBezierPath(roundedRect: panel.offsetBy(dx: 0, dy: 6), xRadius: 28, yRadius: 28)
        NSColor.black.withAlphaComponent(0.18).setFill(); shadow.fill()
        let path = NSBezierPath(roundedRect: panel, xRadius: 28, yRadius: 28)
        NSGraphicsContext.saveGraphicsState(); path.addClip()
        NSGradient(colors: [hex(0xffffff, 0.96), hex(0xf8fbff, 0.94), hex(0xfff7fb, 0.93)])?.draw(in: panel, angle: -18)
        drawSoftAurora(panel)
        NSGraphicsContext.restoreGraphicsState()
        NSColor.white.withAlphaComponent(0.82).setStroke(); path.lineWidth = 1.4; path.stroke()

        let snapshot = countdownSnapshot()
        let total = max(Int(snapshot.remaining.rounded(.up)), 0)
        let text = snapshot.done ? "00:00:00" : String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 34, weight: .black), .foregroundColor: snapshot.done ? hex(0x05a66b) : hex(0x20172f)]
        let textSize = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: panel.midX - textSize.width / 2, y: panel.minY + 20), withAttributes: attrs)
        let range = "\(CountdownTimes.text(times.start)) - \(CountdownTimes.text(times.end))"
        let rangeAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .semibold), .foregroundColor: hex(0x6f627d)]
        let rangeSize = range.size(withAttributes: rangeAttrs)
        range.draw(at: NSPoint(x: panel.midX - rangeSize.width / 2, y: panel.minY + 61), withAttributes: rangeAttrs)

        let bar = NSRect(x: panel.minX + 26, y: panel.minY + 88, width: panel.width - 52, height: 16)
        let track = NSBezierPath(roundedRect: bar, xRadius: 8, yRadius: 8)
        NSColor.white.withAlphaComponent(0.70).setFill(); track.fill()
        let fill = NSRect(x: bar.minX, y: bar.minY, width: max(6, bar.width * snapshot.progress), height: bar.height)
        let fillPath = NSBezierPath(roundedRect: fill, xRadius: 8, yRadius: 8)
        NSGraphicsContext.saveGraphicsState(); fillPath.addClip()
        let colors = snapshot.done ? [hex(0x2ee59d), hex(0x00d4ff), hex(0xffd166)] : [hex(0x00d4ff), hex(0x7c3aed), hex(0xff4d8d), hex(0xffd166)]
        NSGradient(colors: colors)?.draw(in: bar, angle: 0)
        NSGraphicsContext.restoreGraphicsState()
        NSColor.white.withAlphaComponent(0.45).setStroke()
        let shine = NSBezierPath(); shine.lineWidth = 1.2; shine.move(to: NSPoint(x: bar.minX + 7, y: bar.minY + 4)); shine.line(to: NSPoint(x: bar.maxX - 7, y: bar.minY + 4)); shine.stroke()
        drawMilestones(bar, progress: snapshot.progress)
        let truckX = min(max(bar.minX + bar.width * snapshot.progress, bar.minX + 17), bar.maxX - 17)
        drawTruck(NSPoint(x: truckX, y: bar.minY - 19), moving: !snapshot.done)
        drawPomodoroIfNeeded(panel)
    }

    private func hex(_ value: Int, _ alpha: CGFloat = 1) -> NSColor {
        NSColor(calibratedRed: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255, blue: CGFloat(value & 255) / 255, alpha: alpha)
    }

    private func drawSoftAurora(_ rect: NSRect) {
        let blobs: [(Int, CGFloat, NSRect)] = [
            (0x00d4ff, 0.23, NSRect(x: rect.minX - 18, y: rect.minY + 10, width: 130, height: 72)),
            (0xff4d8d, 0.18, NSRect(x: rect.midX - 42, y: rect.minY - 20, width: 155, height: 88)),
            (0xffd166, 0.20, NSRect(x: rect.maxX - 118, y: rect.minY + 12, width: 126, height: 78)),
            (0x2ee59d, 0.16, NSRect(x: rect.maxX - 165, y: rect.maxY - 68, width: 112, height: 58))
        ]
        for blob in blobs { NSGradient(colors: [hex(blob.0, blob.1), hex(blob.0, 0)])?.draw(in: NSBezierPath(ovalIn: blob.2), relativeCenterPosition: .zero) }
    }

    private func drawMilestones(_ bar: NSRect, progress: CGFloat) {
        for index in 1...7 {
            let milestone = CGFloat(index) / 8
            let x = bar.minX + bar.width * milestone
            let reached = progress >= milestone
            hex(reached ? 0xffffff : 0x20172f, reached ? 0.88 : 0.14).setFill()
            NSBezierPath(ovalIn: NSRect(x: x - 5.5, y: bar.midY - 5.5, width: 11, height: 11)).fill()
            hex(reached ? 0xff4d8d : 0xffffff, reached ? 0.95 : 0.55).setFill()
            NSBezierPath(ovalIn: NSRect(x: x - 3, y: bar.midY - 3, width: 6, height: 6)).fill()
        }
    }

    private func drawTruck(_ point: NSPoint, moving: Bool) {
        let bounce = moving ? sin(tick * 2) * 0.9 : 0
        let x = point.x - 18, y = point.y + bounce
        hex(0x20172f, 0.08).setFill(); NSBezierPath(ovalIn: NSRect(x: x + 3, y: y + 28, width: 31, height: 5)).fill()
        hex(0xff4d8d).setFill(); NSBezierPath(roundedRect: NSRect(x: x + 3, y: y + 9, width: 20, height: 13), xRadius: 5, yRadius: 5).fill()
        hex(0xffc857).setFill(); NSBezierPath(roundedRect: NSRect(x: x + 22, y: y + 12, width: 12, height: 10), xRadius: 4, yRadius: 4).fill()
        hex(0xeaffff).setFill(); NSBezierPath(roundedRect: NSRect(x: x + 25, y: y + 14, width: 6, height: 4), xRadius: 1.5, yRadius: 1.5).fill()
        hex(0x261b3f).setFill(); NSBezierPath(ovalIn: NSRect(x: x + 7, y: y + 20, width: 7, height: 7)).fill(); NSBezierPath(ovalIn: NSRect(x: x + 25, y: y + 20, width: 7, height: 7)).fill()
        NSColor.white.withAlphaComponent(0.86).setFill(); NSBezierPath(ovalIn: NSRect(x: x + 9, y: y + 22, width: 3, height: 3)).fill(); NSBezierPath(ovalIn: NSRect(x: x + 27, y: y + 22, width: 3, height: 3)).fill()
    }

    private func drawPomodoroIfNeeded(_ rect: NSRect) {
        guard let end = pomodoroEnd else { return }
        let remaining = max(end.timeIntervalSinceNow, 0)
        if remaining <= 0 { pomodoroEnd = nil; DispatchQueue.main.async { [weak self] in self?.owner?.syncCompactSize(animated: true) }; return }
        let progress = CGFloat(1 - remaining / max(pomodoroTotal, 1))
        let row = NSRect(x: rect.minX + 26, y: rect.minY + 114, width: rect.width - 52, height: 18)
        let track = NSBezierPath(roundedRect: row, xRadius: 9, yRadius: 9); NSColor.white.withAlphaComponent(0.76).setFill(); track.fill()
        let fill = NSRect(x: row.minX, y: row.minY, width: max(10, row.width * progress), height: row.height)
        NSGraphicsContext.saveGraphicsState(); NSBezierPath(roundedRect: fill, xRadius: 9, yRadius: 9).addClip(); NSGradient(colors: [hex(0xffd1dc, 0.92), hex(0xffe4a3, 0.92)])?.draw(in: fill, angle: 0); NSGraphicsContext.restoreGraphicsState()
        hex(0xff2d6f).setFill(); NSBezierPath(ovalIn: NSRect(x: row.minX + 7, y: row.minY + 5, width: 8, height: 8)).fill()
        let seconds = Int(remaining.rounded(.up)), clock = String(format: "%02d:%02d", seconds / 60, seconds % 60)
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .heavy), .foregroundColor: hex(0x20172f)]
        let size = clock.size(withAttributes: attrs); clock.draw(at: NSPoint(x: row.maxX - size.width - 10, y: row.minY + 2.5), withAttributes: attrs)
    }

    private func countdownSnapshot() -> (remaining: TimeInterval, progress: CGFloat, done: Bool) {
        let now = Date(), calendar = Calendar.current
        func date(_ minutes: Int) -> Date {
            var c = calendar.dateComponents([.year, .month, .day], from: now)
            c.hour = minutes / 60; c.minute = minutes % 60; c.second = 0
            return calendar.date(from: c) ?? now
        }
        let start = date(times.start)
        var end = date(times.end)
        if end <= start { end = calendar.date(byAdding: .day, value: 1, to: end) ?? end }
        if now < start { return (start.timeIntervalSince(now), 0, false) }
        if now >= end { return (0, 1, true) }
        let total = max(end.timeIntervalSince(start), 1)
        return (end.timeIntervalSince(now), CGFloat(now.timeIntervalSince(start) / total), false)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var statusItem: NSStatusItem!
    private var root = AuroraBackgroundView()
    private var store = ProjectStore(version: 1, groups: [])
    private var reminderQueue: [(group: Int, project: Int)] = []
    private var reminderIndex = 0
    private var scheduler: Timer?
    private var countdownTimer: Timer?
    private var compactView: CompactCountdownView?
    private var isCompact = false
    private var pendingFocusProjectID: String?
    private var pendingFocusSubgroup: (groupID: String, name: String)?
    private let reminders = [(11, 0), (15, 0), (20, 0)]
    private let encoder: JSONEncoder = {
        let value = JSONEncoder()
        value.outputFormatting = [.prettyPrinted, .sortedKeys]
        value.dateEncodingStrategy = .iso8601
        return value
    }()
    private let decoder: JSONDecoder = {
        let value = JSONDecoder()
        value.dateDecodingStrategy = .iso8601
        return value
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupWindow()
        loadStore()
        showDashboard()
        installExpandedMenu()
        if ProcessInfo.processInfo.arguments.contains("--compact-preview") {
            switchToCompact()
            if ProcessInfo.processInfo.arguments.contains("--pomodoro-preview") { compactView?.startPomodoro(minutes: 25) }
        }
        scheduler = Timer.scheduledTimer(timeInterval: 20, target: self, selector: #selector(checkSchedule), userInfo: nil, repeats: true)
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.compactView?.tick += 0.15
            self?.compactView?.needsDisplay = true
        }
        checkSchedule()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.openWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) { saveStore() }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.title = "📣"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "打开任务跟进", action: #selector(openWindow), keyEquivalent: "o"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        for item in menu.items { item.target = self }
        statusItem.menu = menu
    }

    private func setupWindow() {
        // 这是一个长期摆在桌面上的任务板，不提供容易误触的关闭与最小化按钮。
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 620), styleMask: [.titled, .fullSizeContentView, .resizable], backing: .buffered, defer: false)
        window.minSize = NSSize(width: 700, height: 500)
        window.title = "任务跟进"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        applyBottomLayer()
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(calibratedRed: 0.955, green: 0.965, blue: 0.99, alpha: 1)
        // 多显示器环境下固定放在主屏幕；用户之后仍可拖到任意屏幕。
        if let screen = NSScreen.screens.first?.visibleFrame {
            window.setFrame(NSRect(x: screen.maxX - 840, y: screen.maxY - 640, width: 820, height: 620), display: true)
        }
        window.contentView = root
        openWindow()
    }

    @objc private func openWindow() {
        window.orderBack(nil)
    }

    private func applyBottomLayer() {
        let desktopLevel = Int(CGWindowLevelForKey(.desktopIconWindow)) + 1
        window.level = NSWindow.Level(rawValue: desktopLevel)
        window.orderBack(nil)
    }

    private func installExpandedMenu() {
        let menu = NSMenu()
        let compact = NSMenuItem(title: "变小为下班倒计时", action: #selector(switchToCompact), keyEquivalent: "")
        compact.target = self
        menu.addItem(compact)
        root.menu = menu
    }

    @objc private func switchToCompact() {
        guard !isCompact else { return }
        isCompact = true
        let oldFrame = window.frame
        let size = NSSize(width: 360, height: 150)
        let view = CompactCountdownView(frame: NSRect(origin: .zero, size: size))
        view.owner = self
        compactView = view
        window.styleMask = [.borderless]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.contentView = view
        window.setFrame(NSRect(x: oldFrame.maxX - size.width, y: oldFrame.maxY - size.height, width: size.width, height: size.height), display: true, animate: true)
        applyBottomLayer()
    }

    @objc private func switchToExpanded() {
        guard isCompact else { return }
        isCompact = false
        let oldFrame = window.frame
        compactView = nil
        window.styleMask = [.titled, .fullSizeContentView, .resizable]
        window.titlebarAppearsTransparent = true
        window.isOpaque = true
        window.backgroundColor = NSColor(calibratedRed: 0.955, green: 0.965, blue: 0.99, alpha: 1)
        window.hasShadow = true
        window.contentView = root
        showDashboard()
        installExpandedMenu()
        window.setFrame(NSRect(x: oldFrame.maxX - 820, y: oldFrame.maxY - 620, width: 820, height: 620), display: true, animate: true)
        applyBottomLayer()
    }

    fileprivate func showCompactMenu(_ event: NSEvent, view: NSView) {
        let menu = NSMenu()
        let expand = NSMenuItem(title: "展开项目看板", action: #selector(switchToExpanded), keyEquivalent: "")
        expand.target = self
        menu.addItem(expand)
        let settings = NSMenuItem(title: "设置上下班时间", action: #selector(showCountdownSettings), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)
        let reset = NSMenuItem(title: "恢复 09:00 - 18:00", action: #selector(resetCountdownTimes), keyEquivalent: "")
        reset.target = self
        menu.addItem(reset)
        menu.addItem(.separator())
        let pomodoro25 = NSMenuItem(title: "开始番茄钟 25 分钟", action: #selector(startPomodoro25), keyEquivalent: "")
        pomodoro25.target = self
        menu.addItem(pomodoro25)
        let pomodoro45 = NSMenuItem(title: "开始番茄钟 45 分钟", action: #selector(startPomodoro45), keyEquivalent: "")
        pomodoro45.target = self
        menu.addItem(pomodoro45)
        let stopPomodoro = NSMenuItem(title: "停止番茄钟", action: #selector(stopPomodoroTimer), keyEquivalent: "")
        stopPomodoro.target = self
        menu.addItem(stopPomodoro)
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    fileprivate func syncCompactSize(animated: Bool) {
        guard isCompact, let compactView else { return }
        let size = NSSize(width: 360, height: compactView.hasActivePomodoro ? 170 : 150)
        var frame = window.frame
        let oldMaxY = frame.maxY
        frame.size = size
        frame.origin.y = oldMaxY - size.height
        window.setFrame(frame, display: true, animate: animated)
    }

    @objc private func resetCountdownTimes() {
        compactView?.times = .fallback
        compactView?.needsDisplay = true
    }

    @objc private func startPomodoro25() { compactView?.startPomodoro(minutes: 25) }
    @objc private func startPomodoro45() { compactView?.startPomodoro(minutes: 45) }
    @objc private func stopPomodoroTimer() { compactView?.stopPomodoro() }

    @objc private func showCountdownSettings() {
        guard let compactView else { return }
        let alert = NSAlert()
        alert.messageText = "设置上下班时间"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")
        let stack = NSStackView()
        stack.orientation = .vertical; stack.spacing = 8
        stack.frame = NSRect(x: 0, y: 0, width: 220, height: 60)
        let start = NSTextField(string: CountdownTimes.text(compactView.times.start))
        let end = NSTextField(string: CountdownTimes.text(compactView.times.end))
        stack.addArrangedSubview(start); stack.addArrangedSubview(end); alert.accessoryView = stack
        guard alert.runModal() == .alertFirstButtonReturn,
              let startValue = CountdownTimes.parse(start.stringValue),
              let endValue = CountdownTimes.parse(end.stringValue), startValue != endValue else { return }
        compactView.times = CountdownTimes(start: startValue, end: endValue)
        compactView.needsDisplay = true
    }

    @objc private func quit() { NSApp.terminate(nil) }

    private func resetRoot() {
        root.subviews.forEach { $0.removeFromSuperview() }
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) -> NSTextField {
        let view = NSTextField(wrappingLabelWithString: text)
        view.font = .systemFont(ofSize: size, weight: weight)
        view.textColor = color
        view.maximumNumberOfLines = 0
        return view
    }

    private func button(_ title: String, action: Selector, primary: Bool = false) -> NSButton {
        let view = NSButton(title: title, target: self, action: action)
        view.bezelStyle = .rounded
        view.font = .systemFont(ofSize: 14, weight: primary ? .semibold : .medium)
        view.contentTintColor = primary ? .systemOrange : .labelColor
        view.heightAnchor.constraint(equalToConstant: 34).isActive = true
        return view
    }

    private func compactButton(_ title: String, action: Selector) -> NSButton {
        let view = NSButton(title: title, target: self, action: action)
        view.bezelStyle = .inline
        view.font = .systemFont(ofSize: 11, weight: .medium)
        view.contentTintColor = .secondaryLabelColor
        view.heightAnchor.constraint(equalToConstant: 24).isActive = true
        return view
    }

    private func showDashboard(message: String? = nil) {
        resetRoot()
        let title = label("📣  项目跟进台", size: 27, weight: .bold, color: NSColor(calibratedRed: 0.12, green: 0.16, blue: 0.29, alpha: 1))
        let visibleGroups = store.groups.filter { !($0.isArchived ?? false) }
        let count = visibleGroups.flatMap(\.projects).filter { !($0.isArchived ?? false) && stageTitle($0.status) != "完成" }.count
        let subtitle = label("\(visibleGroups.count) 个分组 · \(count) 个进行中项目  ·  点击任意单元格直接修改", size: 13, weight: .medium, color: NSColor(calibratedRed: 0.35, green: 0.38, blue: 0.52, alpha: 1))

        let spacer = NSView()
        let addGroupButton = compactButton("＋ 分组", action: #selector(addGroup))
        let importButton = compactButton("⇩ 导入", action: #selector(importProjects))
        let topButtons = NSStackView(views: [spacer, addGroupButton, importButton])
        topButtons.orientation = .horizontal
        topButtons.spacing = 6

        let document = FlippedStackView()
        document.orientation = .vertical
        document.alignment = .leading
        document.spacing = 15
        document.edgeInsets = NSEdgeInsets(top: 5, left: 2, bottom: 20, right: 10)

        if store.groups.isEmpty {
            let empty = label("这里还没有项目\n\n新建分组后直接填写，或导入 JSON / CSV。", size: 17, weight: .medium, color: .secondaryLabelColor)
            empty.alignment = .center
            empty.widthAnchor.constraint(equalToConstant: 700).isActive = true
            document.addArrangedSubview(empty)
            document.addArrangedSubview(button("载入示例项目", action: #selector(loadSamples), primary: true))
        } else {
            for (groupIndex, group) in store.groups.enumerated() {
                if group.isArchived ?? false { continue }
                let active = group.projects.enumerated().filter { !($0.element.isArchived ?? false) && stageTitle($0.element.status) != "完成" }
                let tint = groupColor(groupIndex)
                let section = NSStackView()
                section.orientation = .vertical
                section.alignment = .leading
                section.spacing = 0
                section.wantsLayer = true
                section.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.9).cgColor
                section.layer?.cornerRadius = 13
                section.layer?.borderWidth = 1
                section.layer?.borderColor = tint.withAlphaComponent(0.3).cgColor

                let groupName = EditableCell(string: group.name)
                groupName.isBezeled = false
                groupName.drawsBackground = false
                groupName.font = .systemFont(ofSize: 15, weight: .bold)
                groupName.textColor = tint
                groupName.focusRingType = .none
                groupName.onCommit = { [weak self] value in
                    guard !value.isEmpty else { return }
                    self?.store.groups[groupIndex].name = value
                    self?.saveStore()
                }
                let countPill = label("\(active.count) 项", size: 11, weight: .semibold, color: tint)
                let addSubgroup = ClosureButton(title: "＋ 小分组") { [weak self] in self?.addSubgroup(groupIndex: groupIndex) }
                addSubgroup.contentTintColor = tint
                addSubgroup.font = .systemFont(ofSize: 12, weight: .semibold)
                let add = NSButton(title: "＋ 项目", target: self, action: #selector(addProject(_:)))
                add.tag = groupIndex
                add.isBordered = false
                add.contentTintColor = tint
                add.font = .systemFont(ofSize: 12, weight: .semibold)
                let removeGroup = NSButton(title: "×", target: self, action: #selector(archiveGroup(_:)))
                removeGroup.tag = groupIndex
                removeGroup.isBordered = false
                removeGroup.toolTip = "移除分组（可恢复）"
                removeGroup.contentTintColor = .tertiaryLabelColor
                let groupHeader = NSStackView(views: [groupName, countPill, NSView(), addSubgroup, add, removeGroup])
                groupHeader.orientation = .horizontal
                groupHeader.alignment = .centerY
                groupHeader.spacing = 8
                groupHeader.edgeInsets = NSEdgeInsets(top: 9, left: 12, bottom: 9, right: 10)
                groupHeader.wantsLayer = true
                groupHeader.layer?.backgroundColor = tint.withAlphaComponent(0.12).cgColor
                groupHeader.widthAnchor.constraint(equalToConstant: 730).isActive = true
                section.addArrangedSubview(groupHeader)

                appendProjectTable(to: section, items: active.filter { ($0.element.subgroup ?? "").isEmpty }, groupIndex: groupIndex, tint: tint, subgroup: nil)
                for subgroup in group.subgroups ?? [] {
                    let subgroupItems = active.filter { $0.element.subgroup == subgroup }
                    let smallHeader = NSStackView()
                    smallHeader.orientation = .horizontal
                    smallHeader.alignment = .centerY
                    smallHeader.edgeInsets = NSEdgeInsets(top: 8, left: 20, bottom: 6, right: 12)
                    let dot = label("◆", size: 9, color: tint)
                    let smallName = EditableCell(string: subgroup)
                    smallName.isBezeled = false
                    smallName.drawsBackground = false
                    smallName.font = .systemFont(ofSize: 12, weight: .semibold)
                    smallName.textColor = tint
                    smallName.focusRingType = .none
                    smallName.widthAnchor.constraint(equalToConstant: 220).isActive = true
                    smallName.onCommit = { [weak self] value in
                        self?.renameSubgroup(groupIndex: groupIndex, oldName: subgroup, newName: value)
                    }
                    if pendingFocusSubgroup?.groupID == group.id && pendingFocusSubgroup?.name == subgroup {
                        pendingFocusSubgroup = nil
                        DispatchQueue.main.async { [weak self, weak smallName] in
                            guard let smallName else { return }
                            self?.window.makeFirstResponder(smallName)
                            smallName.selectText(nil)
                        }
                    }
                    let addInside = ClosureButton(title: "＋ 项目") { [weak self] in self?.insertProject(groupIndex: groupIndex, subgroup: subgroup) }
                    addInside.contentTintColor = tint
                    addInside.font = .systemFont(ofSize: 11, weight: .semibold)
                    smallHeader.addArrangedSubview(dot)
                    smallHeader.addArrangedSubview(smallName)
                    smallHeader.addArrangedSubview(NSView())
                    smallHeader.addArrangedSubview(addInside)
                    smallHeader.widthAnchor.constraint(equalToConstant: 730).isActive = true
                    section.addArrangedSubview(smallHeader)
                    appendProjectTable(to: section, items: subgroupItems, groupIndex: groupIndex, tint: tint, subgroup: subgroup)
                }
                document.addArrangedSubview(section)
            }

            let completed = completedProjects()
            if !completed.isEmpty { document.addArrangedSubview(completedSection(completed)) }
            let removed = store.groups.enumerated().filter { $0.element.isArchived ?? false }
            if !removed.isEmpty { document.addArrangedSubview(archivedGroupsSection(removed)) }
        }

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = false
        scroll.hasHorizontalScroller = false
        scroll.drawsBackground = false
        scroll.documentView = document
        document.translatesAutoresizingMaskIntoConstraints = false
        document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor, constant: -8).isActive = true

        let stack = NSStackView(views: [title, subtitle])
        if let message {
            stack.addArrangedSubview(label(message, size: 12, weight: .medium, color: .systemGreen))
        }
        stack.addArrangedSubview(topButtons)
        stack.addArrangedSubview(scroll)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 11
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 30),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -30),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 44),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -20),
            topButtons.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func groupColor(_ index: Int) -> NSColor {
        let colors: [NSColor] = [.systemIndigo, .systemPink, .systemTeal, .systemOrange, .systemPurple, .systemBlue]
        return colors[index % colors.count]
    }

    private func statusColor(_ status: String) -> NSColor {
        switch status {
        case "方案中": return .systemPurple
        case "设计中": return .systemPink
        case "dpm中": return .systemIndigo
        case "de中": return .systemTeal
        case "开发中": return .systemBlue
        case "测试中": return .systemOrange
        case "实验中": return .systemGreen
        case "完成": return .systemGreen
        default: return .systemPurple
        }
    }

    private func stageTitle(_ stored: String?) -> String {
        let stages = ["方案中", "设计中", "dpm中", "de中", "开发中", "测试中", "实验中", "完成"]
        guard let stored, stages.contains(stored) else { return "方案中" }
        return stored
    }

    private func editableCell(_ value: String, placeholder: String, width: CGFloat, commit: @escaping (String) -> Void) -> EditableCell {
        let field = EditableCell(string: value)
        field.placeholderString = placeholder
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .exterior
        field.font = .systemFont(ofSize: 13)
        field.lineBreakMode = .byTruncatingTail
        field.onCommit = commit
        field.widthAnchor.constraint(equalToConstant: width).isActive = true
        return field
    }

    private func tableRow(_ titles: [String], widths: [CGFloat], header: Bool) -> NSStackView {
        let cells = zip(titles, widths).map { title, width -> NSView in
            let cell = label(title, size: 11, weight: header ? .semibold : .regular, color: .secondaryLabelColor)
            cell.widthAnchor.constraint(equalToConstant: width).isActive = true
            return cell
        }
        let row = NSStackView(views: cells)
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.edgeInsets = NSEdgeInsets(top: 8, left: 14, bottom: 8, right: 10)
        row.widthAnchor.constraint(equalToConstant: 730).isActive = true
        return row
    }

    private func appendProjectTable(to section: NSStackView, items: [(offset: Int, element: Project)], groupIndex: Int, tint: NSColor, subgroup: String?) {
        guard !items.isEmpty else { return }
        section.addArrangedSubview(tableRow(["", "项目", "状态", "当前进度 / 下一步", "上次跟进", ""], widths: [22, 120, 100, 240, 140, 36], header: true))
        for (rowNumber, item) in items.enumerated() {
            let projectIndex = item.offset
            let project = item.element
            let handle = ProjectDragHandle()
            handle.toolTip = "拖动项目调整排序"
            handle.onReorder = { [weak self] offset in
                self?.moveProjectByOffset(groupIndex: groupIndex, projectIndex: projectIndex, subgroup: subgroup, offset: offset)
            }
            handle.widthAnchor.constraint(equalToConstant: 22).isActive = true
            let name = editableCell(project.name, placeholder: "项目名称", width: 120) { [weak self] value in
                guard !value.isEmpty else { return }
                self?.store.groups[groupIndex].projects[projectIndex].name = value
                self?.saveStore()
            }
            if pendingFocusProjectID == project.id {
                pendingFocusProjectID = nil
                DispatchQueue.main.async { [weak self, weak name] in
                    guard let name else { return }
                    self?.window.makeFirstResponder(name)
                    name.selectText(nil)
                }
            }
            let status = NSPopUpButton(frame: .zero, pullsDown: false)
            status.addItems(withTitles: ["方案中", "设计中", "dpm中", "de中", "开发中", "测试中", "实验中", "完成"])
            let currentStage = stageTitle(project.status)
            status.selectItem(withTitle: currentStage)
            status.font = .systemFont(ofSize: 12, weight: .semibold)
            status.isBordered = false
            status.contentTintColor = statusColor(currentStage)
            status.wantsLayer = true
            status.layer?.cornerRadius = 7
            status.layer?.backgroundColor = statusColor(currentStage).withAlphaComponent(0.16).cgColor
            status.tag = groupIndex * 10_000 + projectIndex
            status.target = self
            status.action = #selector(changeStatus(_:))
            status.widthAnchor.constraint(equalToConstant: 100).isActive = true
            let progress = editableCell(project.progress ?? "", placeholder: "填写进度…", width: 240) { [weak self] value in
                self?.store.groups[groupIndex].projects[projectIndex].progress = value
                self?.saveStore()
            }
            let followed = label(followedText(project.lastFollowedAt), size: 11, color: project.lastFollowedAt == nil ? .tertiaryLabelColor : .systemGreen)
            followed.widthAnchor.constraint(equalToConstant: 140).isActive = true
            let archive = NSButton(title: "×", target: self, action: #selector(archiveProject(_:)))
            archive.tag = groupIndex * 10_000 + projectIndex
            archive.isBordered = false
            archive.toolTip = "归档项目"
            archive.contentTintColor = .tertiaryLabelColor
            archive.widthAnchor.constraint(equalToConstant: 36).isActive = true
            let row = NSStackView(views: [handle, name, status, progress, followed, archive])
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 8
            row.edgeInsets = NSEdgeInsets(top: 9, left: subgroup == nil ? 14 : 24, bottom: 9, right: 10)
            row.widthAnchor.constraint(equalToConstant: 730).isActive = true
            row.wantsLayer = true
            row.layer?.backgroundColor = (rowNumber % 2 == 0 ? NSColor.white : tint.withAlphaComponent(0.035)).cgColor
            section.addArrangedSubview(row)
        }
    }

    private func completedProjects() -> [(Int, Int, Project, String)] {
        var result: [(Int, Int, Project, String)] = []
        for (groupIndex, group) in store.groups.enumerated() {
            if group.isArchived ?? false { continue }
            for (projectIndex, project) in group.projects.enumerated() where !(project.isArchived ?? false) && stageTitle(project.status) == "完成" {
                result.append((groupIndex, projectIndex, project, group.name))
            }
        }
        return result
    }

    private func completedSection(_ items: [(Int, Int, Project, String)]) -> NSView {
        let section = NSStackView()
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 0
        section.wantsLayer = true
        section.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.06).cgColor
        section.layer?.cornerRadius = 13
        section.layer?.borderWidth = 1
        section.layer?.borderColor = NSColor.systemGreen.withAlphaComponent(0.35).cgColor
        let header = label("✓  已完成  ·  \(items.count) 项", size: 14, weight: .bold, color: .systemGreen)
        header.drawsBackground = true
        header.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.1)
        header.widthAnchor.constraint(equalToConstant: 730).isActive = true
        section.addArrangedSubview(header)
        section.addArrangedSubview(tableRow(["项目", "原分组", "完成进度", "上次跟进", ""], widths: [150, 100, 240, 140, 40], header: true))
        for (groupIndex, projectIndex, project, groupName) in items {
            let projectName = label(project.name, size: 13, weight: .medium)
            projectName.widthAnchor.constraint(equalToConstant: 150).isActive = true
            let origin = label(groupName, size: 12, color: .secondaryLabelColor)
            origin.widthAnchor.constraint(equalToConstant: 100).isActive = true
            let progress = label(project.progress ?? "", size: 12, color: .secondaryLabelColor)
            progress.widthAnchor.constraint(equalToConstant: 240).isActive = true
            let followed = label(followedText(project.lastFollowedAt), size: 11, color: .systemGreen)
            followed.widthAnchor.constraint(equalToConstant: 140).isActive = true
            let restore = ClosureButton(title: "↩") { [weak self] in
                self?.store.groups[groupIndex].projects[projectIndex].status = "方案中"
                self?.saveStore()
                self?.showDashboard(message: "项目已移回原分组")
            }
            restore.toolTip = "移回原分组"
            restore.contentTintColor = .systemGreen
            restore.widthAnchor.constraint(equalToConstant: 40).isActive = true
            let row = NSStackView(views: [projectName, origin, progress, followed, restore])
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 8
            row.edgeInsets = NSEdgeInsets(top: 9, left: 14, bottom: 9, right: 10)
            row.widthAnchor.constraint(equalToConstant: 730).isActive = true
            section.addArrangedSubview(row)
        }
        return section
    }

    private func archivedGroupsSection(_ items: [(offset: Int, element: ProjectGroup)]) -> NSView {
        let section = NSStackView()
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 0
        section.wantsLayer = true
        section.layer?.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(0.06).cgColor
        section.layer?.cornerRadius = 13
        let header = label("已移除分组  ·  \(items.count) 个", size: 13, weight: .semibold, color: .secondaryLabelColor)
        header.widthAnchor.constraint(equalToConstant: 730).isActive = true
        section.addArrangedSubview(header)
        for item in items {
            let name = label(item.element.name, size: 12, weight: .medium, color: .secondaryLabelColor)
            let count = label("\(item.element.projects.count) 个项目", size: 11, color: .tertiaryLabelColor)
            let restore = NSButton(title: "恢复", target: self, action: #selector(restoreGroup(_:)))
            restore.tag = item.offset
            restore.isBordered = false
            restore.contentTintColor = .systemBlue
            let row = NSStackView(views: [name, count, NSView(), restore])
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 10
            row.edgeInsets = NSEdgeInsets(top: 8, left: 14, bottom: 8, right: 12)
            row.widthAnchor.constraint(equalToConstant: 730).isActive = true
            section.addArrangedSubview(row)
        }
        return section
    }

    private func followedText(_ date: Date?) -> String {
        guard let date else { return "尚未跟进" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm 已跟进"
        return formatter.string(from: date)
    }

    @objc private func addGroup() {
        let alert = NSAlert()
        alert.messageText = "新建项目分组"
        alert.informativeText = "例如：增长项目、产品迭代、客户合作"
        alert.addButton(withTitle: "创建")
        alert.addButton(withTitle: "取消")
        let input = NSTextField(string: "")
        input.placeholderString = "分组名称"
        input.frame = NSRect(x: 0, y: 0, width: 300, height: 26)
        alert.accessoryView = input
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let project = Project(id: UUID().uuidString, name: "未命名项目", progress: "点击填写下一步", owner: nil, lastFollowedAt: nil, isArchived: false, status: "方案中")
        store.groups.append(ProjectGroup(id: UUID().uuidString, name: name, projects: [project]))
        saveStore()
        showDashboard(message: "已创建“\(name)”")
    }

    @objc private func addProject(_ sender: NSButton) {
        insertProject(groupIndex: sender.tag, subgroup: nil)
    }

    private func insertProject(groupIndex: Int, subgroup: String?) {
        guard store.groups.indices.contains(groupIndex) else { return }
        let id = UUID().uuidString
        store.groups[groupIndex].projects.append(Project(id: id, name: "未命名项目", progress: "", owner: nil, lastFollowedAt: nil, isArchived: false, status: "方案中", subgroup: subgroup))
        pendingFocusProjectID = id
        saveStore()
        showDashboard()
    }

    private func addSubgroup(groupIndex: Int) {
        guard store.groups.indices.contains(groupIndex) else { return }
        var subgroups = store.groups[groupIndex].subgroups ?? []
        var suffix = 1
        var name = "未命名小分组"
        while subgroups.contains(name) {
            suffix += 1
            name = "未命名小分组 \(suffix)"
        }
        subgroups.append(name)
        store.groups[groupIndex].subgroups = subgroups
        pendingFocusSubgroup = (store.groups[groupIndex].id, name)
        saveStore()
        showDashboard()
    }

    private func renameSubgroup(groupIndex: Int, oldName: String, newName rawValue: String) {
        guard store.groups.indices.contains(groupIndex) else { return }
        let newName = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, newName != oldName else { return }
        var subgroups = store.groups[groupIndex].subgroups ?? []
        guard !subgroups.contains(newName), let index = subgroups.firstIndex(of: oldName) else { return }
        subgroups[index] = newName
        store.groups[groupIndex].subgroups = subgroups
        for projectIndex in store.groups[groupIndex].projects.indices where store.groups[groupIndex].projects[projectIndex].subgroup == oldName {
            store.groups[groupIndex].projects[projectIndex].subgroup = newName
        }
        saveStore()
        showDashboard()
    }

    private func moveProjectByOffset(groupIndex: Int, projectIndex: Int, subgroup: String?, offset: Int) {
        guard store.groups.indices.contains(groupIndex), store.groups[groupIndex].projects.indices.contains(projectIndex) else { return }
        let peerIndices = store.groups[groupIndex].projects.indices.filter { index in
            let project = store.groups[groupIndex].projects[index]
            return !(project.isArchived ?? false) && stageTitle(project.status) != "完成" && (project.subgroup ?? "") == (subgroup ?? "")
        }
        guard let currentPeerIndex = peerIndices.firstIndex(of: projectIndex) else { return }
        let targetPeerIndex = max(0, min(currentPeerIndex + offset, peerIndices.count - 1))
        guard currentPeerIndex != targetPeerIndex else { return }
        let targetProjectIndex = peerIndices[targetPeerIndex]
        var projects = store.groups[groupIndex].projects
        let moved = projects.remove(at: projectIndex)
        var insertionIndex = targetProjectIndex
        if projectIndex < targetProjectIndex { insertionIndex -= 1 }
        if targetPeerIndex > currentPeerIndex { insertionIndex += 1 }
        projects.insert(moved, at: max(0, min(insertionIndex, projects.count)))
        store.groups[groupIndex].projects = projects
        saveStore()
        showDashboard()
    }

    @objc private func archiveGroup(_ sender: NSButton) {
        let groupIndex = sender.tag
        guard store.groups.indices.contains(groupIndex) else { return }
        let alert = NSAlert()
        alert.messageText = "移除“\(store.groups[groupIndex].name)”？"
        alert.informativeText = "分组和其中的项目会收进“已移除分组”，之后可以恢复。"
        alert.addButton(withTitle: "移除")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        store.groups[groupIndex].isArchived = true
        saveStore()
        showDashboard()
    }

    @objc private func restoreGroup(_ sender: NSButton) {
        guard store.groups.indices.contains(sender.tag) else { return }
        store.groups[sender.tag].isArchived = false
        saveStore()
        showDashboard()
    }

    @objc private func changeStatus(_ sender: NSPopUpButton) {
        let groupIndex = sender.tag / 10_000
        let projectIndex = sender.tag % 10_000
        guard store.groups.indices.contains(groupIndex), store.groups[groupIndex].projects.indices.contains(projectIndex) else { return }
        let newStatus = sender.titleOfSelectedItem ?? "方案中"
        store.groups[groupIndex].projects[projectIndex].status = newStatus
        saveStore()
        showDashboard(message: newStatus == "完成" ? "项目已移入“已完成”" : "状态已更新")
    }

    @objc private func archiveProject(_ sender: NSButton) {
        let groupIndex = sender.tag / 10_000
        let projectIndex = sender.tag % 10_000
        guard store.groups.indices.contains(groupIndex), store.groups[groupIndex].projects.indices.contains(projectIndex) else { return }
        store.groups[groupIndex].projects[projectIndex].isArchived = true
        saveStore()
        showDashboard(message: "项目已归档")
    }

    @objc private func loadSamples() {
        store = ProjectStore(version: 1, groups: [
            ProjectGroup(id: "growth", name: "增长项目", projects: [
                Project(id: "launch", name: "新品发布", progress: "等待设计稿终版", owner: nil, lastFollowedAt: nil, isArchived: false, status: "设计中"),
                Project(id: "review", name: "渠道复盘", progress: "待确认下周会议时间", owner: nil, lastFollowedAt: nil, isArchived: false, status: "方案中")
            ]),
            ProjectGroup(id: "product", name: "产品迭代", projects: [
                Project(id: "search", name: "搜索优化", progress: "等待灰度数据", owner: nil, lastFollowedAt: nil, isArchived: false, status: "实验中")
            ])
        ])
        saveStore()
        showDashboard(message: "示例项目已载入")
    }

    @objc private func importProjects() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json, .commaSeparatedText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try self?.readImport(url)
                self?.saveStore()
                self?.showDashboard(message: "已导入 \(url.lastPathComponent)")
            } catch {
                self?.showError("导入失败", detail: error.localizedDescription)
            }
        }
    }

    private func readImport(_ url: URL) throws {
        if url.pathExtension.lowercased() == "json" {
            store = try decoder.decode(ProjectStore.self, from: Data(contentsOf: url))
            return
        }
        let text = try String(contentsOf: url, encoding: .utf8)
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.count > 1 else { throw NSError(domain: "FollowUpBell", code: 1, userInfo: [NSLocalizedDescriptionKey: "CSV 没有项目数据"])}
        var groups: [String: [Project]] = [:]
        var order: [String] = []
        for line in lines.dropFirst() {
            let columns = parseCSV(line)
            guard columns.count >= 2 else { continue }
            let groupName = columns[0].trimmingCharacters(in: .whitespaces)
            let projectName = columns[1].trimmingCharacters(in: .whitespaces)
            guard !groupName.isEmpty, !projectName.isEmpty else { continue }
            if groups[groupName] == nil { groups[groupName] = []; order.append(groupName) }
            groups[groupName]?.append(Project(id: slug("\(groupName)-\(projectName)"), name: projectName, progress: columns.count > 2 ? columns[2] : nil, owner: columns.count > 3 ? columns[3] : nil, lastFollowedAt: nil, isArchived: false))
        }
        store = ProjectStore(version: 1, groups: order.map { ProjectGroup(id: slug($0), name: $0, projects: groups[$0] ?? []) })
    }

    private func parseCSV(_ line: String) -> [String] {
        var values: [String] = [], current = "", quoted = false
        for char in line {
            if char == "\"" { quoted.toggle() }
            else if char == "," && !quoted { values.append(current); current = "" }
            else { current.append(char) }
        }
        values.append(current)
        return values
    }

    private func slug(_ value: String) -> String {
        let cleaned = value.lowercased().unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character(String($0)) : "-" }
        return String(cleaned).replacingOccurrences(of: "--", with: "-")
    }

    @objc private func startReminder() {
        if isCompact { switchToExpanded() }
        reminderQueue = []
        for (groupIndex, group) in store.groups.enumerated() {
            if group.isArchived ?? false { continue }
            for (projectIndex, project) in group.projects.enumerated() where !(project.isArchived ?? false) && stageTitle(project.status) != "完成" {
                reminderQueue.append((groupIndex, projectIndex))
            }
        }
        reminderIndex = 0
        guard !reminderQueue.isEmpty else {
            showError("没有可提醒项目", detail: "请先导入项目，或载入示例项目。")
            return
        }
        showReminder()
        openWindow()
    }

    private func showReminder() {
        guard reminderIndex < reminderQueue.count else {
            showDashboard(message: "这一轮全部跟进完了 ✓")
            return
        }
        resetRoot()
        let pointer = reminderQueue[reminderIndex]
        let project = store.groups[pointer.group].projects[pointer.project]
        let group = store.groups[pointer.group].name

        let progress = label("\(reminderIndex + 1) / \(reminderQueue.count)  ·  \(group)", size: 13, weight: .semibold, color: .secondaryLabelColor)
        let person = label("🧑‍💼📣", size: 72)
        person.alignment = .center
        let question = label("你【\(project.name)】\n有没有去跟进度了？", size: 24, weight: .bold)
        question.alignment = .center
        let context = label("当前进度：\(project.progress?.isEmpty == false ? project.progress! : "待补充")", size: 14, color: .secondaryLabelColor)
        context.alignment = .center
        let done = button("有了有了", action: #selector(confirmFollowed), primary: true)
        done.keyEquivalent = "\r"
        done.heightAnchor.constraint(equalToConstant: 44).isActive = true
        let later = button("先回列表", action: #selector(backToDashboard))

        let stack = NSStackView(views: [progress, person, question, context, done, later])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: root.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: root.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -28),
            done.widthAnchor.constraint(equalToConstant: 260),
            later.widthAnchor.constraint(equalToConstant: 260)
        ])
    }

    @objc private func confirmFollowed() {
        guard reminderIndex < reminderQueue.count else { return }
        let pointer = reminderQueue[reminderIndex]
        store.groups[pointer.group].projects[pointer.project].lastFollowedAt = Date()
        saveStore()
        reminderIndex += 1
        showReminder()
    }

    @objc private func backToDashboard() { showDashboard() }

    @objc private func checkSchedule() {
        let calendar = Calendar.current
        let now = Date()
        let parts = calendar.dateComponents([.hour, .minute], from: now)
        guard let hour = parts.hour, let minute = parts.minute else { return }
        for (scheduledHour, scheduledMinute) in reminders where hour == scheduledHour && minute == scheduledMinute {
            let day = ISO8601DateFormatter().string(from: calendar.startOfDay(for: now))
            let key = "fired.\(day).\(scheduledHour).\(scheduledMinute)"
            if !UserDefaults.standard.bool(forKey: key) {
                UserDefaults.standard.set(true, forKey: key)
                startReminder()
            }
        }
    }

    private var dataURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("FollowUpBell", isDirectory: true).appendingPathComponent("projects.json")
    }

    private func loadStore() {
        guard let data = try? Data(contentsOf: dataURL), let decoded = try? decoder.decode(ProjectStore.self, from: data) else { return }
        store = decoded
    }

    private func saveStore() {
        do {
            try FileManager.default.createDirectory(at: dataURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try encoder.encode(store).write(to: dataURL, options: .atomic)
        } catch { showError("保存失败", detail: error.localizedDescription) }
    }

    private func showError(_ title: String, detail: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.alertStyle = .warning
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
