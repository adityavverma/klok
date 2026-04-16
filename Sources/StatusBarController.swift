import AppKit
import EventKit
import Foundation

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var secondTimer: Timer?      // fires every second, aligned
    private var minuteTimer: Timer?      // fires every minute for event refresh
    private var eventMonitor: Any?
    private var prefsWindowController: PreferencesWindowController?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        super.init()
        setup()

        NotificationCenter.default.addObserver(self, selector: #selector(onSettingsChanged),
                                               name: .settingsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onEventsChanged),
                                               name: .eventsChanged, object: nil)

        // Request calendar access on launch
        EventManager.shared.requestAccess { [weak self] _ in self?.updateDisplay() }
    }

    private func setup() {
        setupButton()
        setupPopover()
        startAlignedTimer()
        setupEventMonitor()
    }

    private func setupButton() {
        guard let btn = statusItem.button else { return }
        btn.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize - 0.5, weight: .regular)
        btn.target = self
        btn.action = #selector(buttonClicked(_:))
        btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateDisplay()
    }

    private func setupPopover() {
        popover.behavior = .transient
        popover.animates = true

        let vc = PopoverViewController()
        vc.onSettingsTapped = { [weak self] in self?.showPreferences() }
        popover.contentViewController = vc
        // Size is driven by vc.preferredContentSize set inside buildUI()
    }

    // Aligns the 1-second timer to actual wall-clock second boundaries
    private func startAlignedTimer() {
        updateDisplay() // immediate

        let now = Date().timeIntervalSinceReferenceDate
        let delay = 1.0 - now.truncatingRemainder(dividingBy: 1.0)

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            self.secondTick()
            self.secondTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.secondTick()
            }
            RunLoop.main.add(self.secondTimer!, forMode: .common)
        }

        // Minute timer for event refresh
        minuteTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updateDisplay()
            if self?.popover.isShown == true {
                (self?.popover.contentViewController as? PopoverViewController)?.refreshEvents()
            }
        }
        RunLoop.main.add(minuteTimer!, forMode: .common)
    }

    private func secondTick() {
        updateDisplay()
        if popover.isShown {
            (popover.contentViewController as? PopoverViewController)?.tick()
        }
    }

    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.popover.isShown == true { self?.closePopover() }
        }
    }

    // MARK: - Display

    func updateDisplay() {
        guard let btn = statusItem.button else { return }
        let now = Date()
        var parts: [String] = [formatLocalTime(now)]

        if AppSettings.showSecondaryInMenuBar {
            for tzId in AppSettings.menuBarClockTimezones.prefix(2) {
                guard let tz = TimeZone(identifier: tzId) else { continue }
                let abbr = tz.abbreviation(for: now) ?? ""
                let t = formatTime(now, timezone: tz, includeDate: false)
                parts.append("\(t) \(abbr)")
            }
        }

        if AppSettings.showNextEventInMenuBar, let event = EventManager.shared.nextEvent() {
            let label = menuBarEventLabel(event)
            parts.append(label)
        }

        btn.title = parts.joined(separator: "  ·  ")
    }

    private func formatLocalTime(_ date: Date) -> String {
        return formatTime(date, timezone: AppSettings.primaryTimezone, includeDate: AppSettings.showDate)
    }

    func formatTime(_ date: Date, timezone: TimeZone, includeDate: Bool) -> String {
        let f = DateFormatter()
        f.timeZone = timezone
        let use24 = AppSettings.use24HourFormat
        let secs = AppSettings.showSeconds
        if includeDate {
            f.dateFormat = use24 ? (secs ? "EEE d MMM  HH:mm:ss" : "EEE d MMM  HH:mm")
                                 : (secs ? "EEE d MMM  h:mm:ss a" : "EEE d MMM  h:mm a")
        } else {
            f.dateFormat = use24 ? (secs ? "HH:mm:ss" : "HH:mm")
                                 : (secs ? "h:mm:ss a" : "h:mm a")
        }
        return f.string(from: date)
    }

    private func menuBarEventLabel(_ event: EKEvent) -> String {
        let now = Date()
        let diff = event.startDate.timeIntervalSince(now)
        let title = event.title ?? "Event"
        let short = title.count > 20 ? String(title.prefix(18)) + "…" : title
        if diff < 60 {
            return "📅 \(short) now"
        } else if diff < 3600 {
            let mins = Int(diff / 60)
            return "📅 \(short) in \(mins)m"
        } else {
            let f = DateFormatter()
            f.timeStyle = .short
            f.timeZone = .current
            return "📅 \(short) at \(f.string(from: event.startDate))"
        }
    }

    // MARK: - Interactions

    @objc private func buttonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp { showContextMenu() }
        else { togglePopover() }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let prefs = NSMenuItem(title: "Preferences…", action: #selector(showPreferences), keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Klok", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func togglePopover() {
        popover.isShown ? closePopover() : openPopover()
    }

    private func openPopover() {
        guard let btn = statusItem.button else { return }
        (popover.contentViewController as? PopoverViewController)?.refresh()
        popover.show(relativeTo: btn.bounds, of: btn, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closePopover() { popover.performClose(nil) }

    @objc func showPreferences() {
        closePopover()
        // Accessory apps can't bring windows to front — briefly become a regular app
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if self.prefsWindowController == nil {
                self.prefsWindowController = PreferencesWindowController()
                self.prefsWindowController?.window?.delegate = self
            }
            self.prefsWindowController?.showWindow(nil)
            self.prefsWindowController?.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func quitApp() { NSApp.terminate(nil) }
    @objc private func onSettingsChanged() { updateDisplay() }
    @objc private func onEventsChanged() { updateDisplay() }

    deinit {
        secondTimer?.invalidate()
        minuteTimer?.invalidate()
        if let m = eventMonitor { NSEvent.removeMonitor(m) }
        NotificationCenter.default.removeObserver(self)
    }
}

extension StatusBarController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        prefsWindowController = nil
        // Go back to accessory mode so no Dock icon lingers
        NSApp.setActivationPolicy(.accessory)
    }
}
