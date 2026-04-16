import AppKit
import EventKit
import Foundation

class PopoverViewController: NSViewController {
    var onSettingsTapped: (() -> Void)?

    let W: CGFloat = 330

    // Fixed section heights
    private let bottomBarH: CGFloat  = 36
    private let clockRowH: CGFloat   = 48
    private let eventRowH: CGFloat   = 52
    private let calHeaderH: CGFloat  = 38
    private let calWeekdayH: CGFloat = 22
    private let calCellH: CGFloat    = 35
    private let joinBannerH: CGFloat = 50
    private let sepH: CGFloat        = 1

    private var calendarView: CalendarView!
    private var eventsView: UpcomingEventsView!
    private var worldClocksView: WorldClocksView!
    private var joinBanner: JoinBannerView?

    override func loadView() {
        view = NSVisualEffectView(frame: .zero)
        (view as? NSVisualEffectView)?.blendingMode = .behindWindow
        (view as? NSVisualEffectView)?.material     = .popover
        (view as? NSVisualEffectView)?.state        = .active
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        NotificationCenter.default.addObserver(self, selector: #selector(onSettingsOrEvents),
                                               name: .settingsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onSettingsOrEvents),
                                               name: .eventsChanged, object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func onSettingsOrEvents() { buildUI() }

    private func buildUI() {
        view.subviews.forEach { $0.removeFromSuperview() }

        // ── Compute heights ───────────────────────────────────────
        let numClocks  = max(1, min(4, AppSettings.worldClockIdentifiers.count))
        let clocksH    = CGFloat(numClocks) * clockRowH

        var eventsH: CGFloat = 0
        var numEvents = 0
        if AppSettings.showUpcomingEvents {
            numEvents  = min(3, EventManager.shared.upcomingEvents(days: 7, max: 3).count)
            eventsH    = CGFloat(max(1, numEvents)) * eventRowH   // at least 1 row (for "no events" msg)
        }

        // Calendar: always allocate 6 rows so height is stable across months
        let calH = calHeaderH + calWeekdayH + 6 * calCellH + 6   // +6 small padding

        // Total height (bottom → top)
        let totalH = bottomBarH + sepH
                   + clocksH   + sepH
                   + (eventsH > 0 ? eventsH + sepH : 0)
                   + calH
                   + 8   // top padding

        let H = totalH
        view.frame             = NSRect(x: 0, y: 0, width: W, height: H)
        preferredContentSize   = NSSize(width: W, height: H)

        // ── Build from bottom up ──────────────────────────────────
        var y: CGFloat = 0

        // Bottom bar
        let bar = buildBottomBar(y: y)
        view.addSubview(bar)
        y += bottomBarH

        addSep(at: y); y += sepH

        // World clocks
        worldClocksView = WorldClocksView(
            frame: NSRect(x: 0, y: y, width: W, height: clocksH))
        view.addSubview(worldClocksView)
        y += clocksH

        addSep(at: y); y += sepH

        // Upcoming events
        if eventsH > 0 {
            eventsView = UpcomingEventsView(
                frame: NSRect(x: 0, y: y, width: W, height: eventsH))
            view.addSubview(eventsView)
            y += eventsH
            addSep(at: y); y += sepH
        }

        // Calendar (fills remaining space exactly)
        calendarView = CalendarView(
            frame: NSRect(x: 0, y: y, width: W, height: calH))
        view.addSubview(calendarView)
        y += calH

        // top padding already accounted in totalH

        // Join banner (overlaid at top when meeting is imminent)
        refreshJoinBanner()
    }

    // MARK: - Bottom bar

    private func buildBottomBar(y: CGFloat) -> NSView {
        let bar = NSView(frame: NSRect(x: 0, y: y, width: W, height: bottomBarH))

        let dotsBtn = NSButton(title: "···", target: self, action: #selector(dotsTapped(_:)))
        dotsBtn.bezelStyle = .rounded; dotsBtn.isBordered = false
        dotsBtn.font = NSFont.systemFont(ofSize: 15, weight: .regular)
        dotsBtn.contentTintColor = .tertiaryLabelColor
        dotsBtn.frame = NSRect(x: 12, y: (bottomBarH - 22) / 2, width: 36, height: 22)
        bar.addSubview(dotsBtn)

        let tzHint = NSTextField(labelWithString: localTZHint())
        tzHint.font = NSFont.systemFont(ofSize: 10.5)
        tzHint.textColor = .tertiaryLabelColor
        tzHint.frame = NSRect(x: 52, y: (bottomBarH - 14) / 2, width: W - 96, height: 14)
        bar.addSubview(tzHint)

        let chevron = NSButton(title: "", target: self, action: #selector(openCalendarApp))
        chevron.image = NSImage(systemSymbolName: "chevron.right",
                                accessibilityDescription: "Open Calendar")
        chevron.bezelStyle = .rounded; chevron.isBordered = false
        chevron.contentTintColor = .tertiaryLabelColor
        chevron.frame = NSRect(x: W - 32, y: (bottomBarH - 20) / 2, width: 20, height: 20)
        bar.addSubview(chevron)

        // top separator
        let sep = NSView(frame: NSRect(x: 0, y: bottomBarH - 1, width: W, height: 1))
        sep.wantsLayer = true
        sep.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
        bar.addSubview(sep)

        return bar
    }

    // MARK: - Join Banner

    func refreshJoinBanner() {
        joinBanner?.removeFromSuperview(); joinBanner = nil
        guard AppSettings.showUpcomingEvents,
              EventManager.shared.isAuthorized,
              let next = EventManager.shared.nextEvent() else { return }
        let diff = next.startDate.timeIntervalSince(Date())
        guard diff < 30 * 60 && diff > -300 else { return }

        let H = view.bounds.height
        let banner = JoinBannerView(
            frame: NSRect(x: 0, y: H - joinBannerH, width: W, height: joinBannerH),
            event: next)
        view.addSubview(banner)
        joinBanner = banner
    }

    // MARK: - Updates

    func tick() { worldClocksView?.tick() }

    func refresh() {
        calendarView?.refresh()
        worldClocksView?.buildRows()
        eventsView?.reload()
        refreshJoinBanner()
    }

    func refreshEvents() {
        eventsView?.reload()
        refreshJoinBanner()
    }

    // MARK: - Helpers

    private func addSep(at y: CGFloat) {
        let s = NSView(frame: NSRect(x: 0, y: y, width: W, height: 1))
        s.wantsLayer = true
        s.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
        view.addSubview(s)
    }

    private func localTZHint() -> String {
        let tz   = AppSettings.primaryTimezone
        let abbr = tz.abbreviation() ?? ""
        let off  = tz.secondsFromGMT()
        let h    = abs(off) / 3600
        let m    = (abs(off) % 3600) / 60
        let sign = off >= 0 ? "+" : "-"
        return m == 0 ? "\(abbr)  UTC\(sign)\(h)"
                      : "\(abbr)  UTC\(sign)\(h):\(String(format:"%02d",m))"
    }

    @objc private func dotsTapped(_ sender: NSButton) {
        let menu = NSMenu()
        let p = NSMenuItem(title: "Preferences…", action: #selector(prefsSelected), keyEquivalent: ",")
        p.target = self; menu.addItem(p)
        menu.addItem(.separator())
        let q = NSMenuItem(title: "Quit Klok", action: #selector(quitSelected), keyEquivalent: "q")
        q.target = self; menu.addItem(q)
        menu.popUp(positioning: menu.items.first,
                   at: NSPoint(x: 0, y: sender.bounds.height + 2), in: sender)
    }

    @objc private func prefsSelected()   { onSettingsTapped?() }
    @objc private func quitSelected()    { NSApp.terminate(nil) }
    @objc private func openCalendarApp() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
    }
}

// MARK: - Join Banner

class JoinBannerView: NSView {
    private let event: EKEvent
    init(frame: NSRect, event: EKEvent) { self.event = event; super.init(frame: frame); build() }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        wantsLayer = true
        let bg = NSView(frame: bounds); bg.wantsLayer = true
        bg.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.07).cgColor
        addSubview(bg)

        let sep = NSView(frame: NSRect(x: 0, y: 0, width: bounds.width, height: 1))
        sep.wantsLayer = true
        sep.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.4).cgColor
        addSubview(sep)

        let joinBtn = NSButton(title: "Join", target: self, action: #selector(joinMeeting))
        joinBtn.bezelStyle = .rounded
        joinBtn.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        joinBtn.frame = NSRect(x: 16, y: (bounds.height - 26) / 2, width: 52, height: 26)
        addSubview(joinBtn)

        let title = NSTextField(labelWithString: event.title ?? "Meeting")
        title.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        title.textColor = .labelColor; title.lineBreakMode = .byTruncatingTail
        title.frame = NSRect(x: 76, y: bounds.height / 2 + 1, width: bounds.width - 92, height: 16)
        addSubview(title)

        let diff    = event.startDate.timeIntervalSince(Date())
        let subtext = diff <= 0 ? "Happening now"
                    : diff < 60 ? "Starting now"
                    : "In \(Int(diff / 60)) minutes"
        let sub = NSTextField(labelWithString: subtext)
        sub.font = NSFont.systemFont(ofSize: 11); sub.textColor = .secondaryLabelColor
        sub.frame = NSRect(x: 76, y: bounds.height / 2 - 14, width: bounds.width - 92, height: 14)
        addSubview(sub)
    }

    @objc private func joinMeeting() {
        let text = ((event.notes ?? "") + (event.url?.absoluteString ?? "")).lowercased()
        for prefix in ["https://zoom.us","https://meet.google","https://teams.microsoft",
                        "https://webex.com","https://whereby.com"] {
            if let r = text.range(of: prefix) {
                let sub = text[r.lowerBound...]
                let end = sub.firstIndex(where: { " \n\r".contains($0) }) ?? sub.endIndex
                if let url = URL(string: String(sub[sub.startIndex..<end])) {
                    NSWorkspace.shared.open(url); return
                }
            }
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
    }
}
