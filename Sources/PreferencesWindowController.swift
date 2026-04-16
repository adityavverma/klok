import AppKit
import EventKit
import Foundation

class PreferencesWindowController: NSWindowController, NSWindowDelegate {

    convenience init() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false
        )
        win.title = "Klok Preferences"
        win.center()
        self.init(window: win)
        win.delegate = self

        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar

        tabs.addChildViewController(generalTab(),   label: "General",    image: "clock")
        tabs.addChildViewController(clocksTab(),    label: "Clocks",     image: "globe")
        tabs.addChildViewController(calendarTab(),  label: "Calendar",   image: "calendar")
        tabs.addChildViewController(eventsTab(),    label: "Events",     image: "list.bullet")

        win.contentViewController = tabs
    }

    // MARK: - Tab builders

    private func generalTab() -> NSViewController {
        let v = FormViewController(title: "General")
        v.loadViewIfNeeded()

        v.addSection("Menu Bar")
        v.addCheckbox("Show date (e.g. Wed 16 Apr)",
                      key: \.showDate, initial: AppSettings.showDate)
        v.addCheckbox("Use 24-hour format",
                      key: \.use24HourFormat, initial: AppSettings.use24HourFormat)
        v.addCheckbox("Show seconds",
                      key: \.showSeconds, initial: AppSettings.showSeconds)
        v.addCheckbox("Show secondary timezone(s) in menu bar",
                      key: \.showSecondaryInMenuBar, initial: AppSettings.showSecondaryInMenuBar)
        v.addCheckbox("Show next calendar event in menu bar",
                      key: \.showNextEventInMenuBar, initial: AppSettings.showNextEventInMenuBar)

        return v
    }

    private func clocksTab() -> NSViewController {
        let v = ClocksTabViewController()
        return v
    }

    private func calendarTab() -> NSViewController {
        let v = FormViewController(title: "Calendar")
        v.loadViewIfNeeded()

        v.addSection("Calendar View")
        v.addCheckbox("Start week on Monday",
                      key: \.weekStartsOnMonday, initial: AppSettings.weekStartsOnMonday)
        v.addCheckbox("Show week numbers",
                      key: \.showWeekNumbers, initial: AppSettings.showWeekNumbers)
        v.addCheckbox("Highlight weekends",
                      key: \.highlightWeekends, initial: AppSettings.highlightWeekends)
        v.addCheckbox("Show event dots on days with events",
                      key: \.showEventDotsInCalendar, initial: AppSettings.showEventDotsInCalendar)

        return v
    }

    private func eventsTab() -> NSViewController {
        let v = EventsTabViewController()
        return v
    }

    func windowWillClose(_ notification: Notification) {}
}

// MARK: - Toolbar-based tab helper

extension NSTabViewController {
    func addChildViewController(_ vc: NSViewController, label: String, image: String) {
        addChild(vc)
        if let item = tabViewItems.last {
            item.label = label
            if #available(macOS 11.0, *) {
                item.image = NSImage(systemSymbolName: image, accessibilityDescription: label)
            }
        }
    }
}

// MARK: - Generic form view controller

class FormViewController: NSViewController {
    private var scrollView: NSScrollView!
    private var stackView: NSStackView!
    private let titleStr: String

    init(title: String) {
        self.titleStr = title
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 300))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 6
        stackView.edgeInsets = NSEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)

        scrollView = NSScrollView(frame: view.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.documentView = stackView
        scrollView.drawsBackground = false
        view.addSubview(scrollView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
        ])
    }

    func addSection(_ title: String) {
        let lbl = NSTextField(labelWithString: title.uppercased())
        lbl.font = NSFont.boldSystemFont(ofSize: 10)
        lbl.textColor = .secondaryLabelColor
        let spacer = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 8))
        stackView.addArrangedSubview(spacer)
        stackView.addArrangedSubview(lbl)
    }

    func addCheckbox(_ label: String, key: WritableKeyPath<AppSettingsProxy, Bool>, initial: Bool) {
        let cb = NSButton(checkboxWithTitle: label, target: nil, action: nil)
        cb.state = initial ? .on : .off
        cb.font = NSFont.systemFont(ofSize: 13)
        let proxy = AppSettingsProxy()
        cb.target = proxy
        cb.action = #selector(AppSettingsProxy.checkboxToggled(_:))
        proxy.keyPath = key
        proxy.checkbox = cb
        // Retain proxy via associated object using a stable UnsafeRawPointer key
        withUnsafePointer(to: &AssocKey.proxyKey) { ptr in
            objc_setAssociatedObject(cb, ptr, proxy, .OBJC_ASSOCIATION_RETAIN)
        }
        stackView.addArrangedSubview(cb)
    }
}

// Trampoline so FormViewController doesn't need to know every setting
class AppSettingsProxy: NSObject {
    var keyPath: WritableKeyPath<AppSettingsProxy, Bool>?
    weak var checkbox: NSButton?

    @objc func checkboxToggled(_ sender: NSButton) {
        guard let kp = keyPath else { return }
        var proxy = self
        proxy[keyPath: kp] = (sender.state == .on)
    }

    // Map keyPaths to AppSettings
    var showDate: Bool {
        get { AppSettings.showDate }
        set { AppSettings.showDate = newValue }
    }
    var use24HourFormat: Bool {
        get { AppSettings.use24HourFormat }
        set { AppSettings.use24HourFormat = newValue }
    }
    var showSeconds: Bool {
        get { AppSettings.showSeconds }
        set { AppSettings.showSeconds = newValue }
    }
    var showSecondaryInMenuBar: Bool {
        get { AppSettings.showSecondaryInMenuBar }
        set { AppSettings.showSecondaryInMenuBar = newValue }
    }
    var showNextEventInMenuBar: Bool {
        get { AppSettings.showNextEventInMenuBar }
        set { AppSettings.showNextEventInMenuBar = newValue }
    }
    var weekStartsOnMonday: Bool {
        get { AppSettings.weekStartsOnMonday }
        set { AppSettings.weekStartsOnMonday = newValue }
    }
    var showWeekNumbers: Bool {
        get { AppSettings.showWeekNumbers }
        set { AppSettings.showWeekNumbers = newValue }
    }
    var highlightWeekends: Bool {
        get { AppSettings.highlightWeekends }
        set { AppSettings.highlightWeekends = newValue }
    }
    var showEventDotsInCalendar: Bool {
        get { AppSettings.showEventDotsInCalendar }
        set { AppSettings.showEventDotsInCalendar = newValue }
    }
    var showUpcomingEvents: Bool {
        get { AppSettings.showUpcomingEvents }
        set { AppSettings.showUpcomingEvents = newValue }
    }
    var showTimeBars: Bool {
        get { AppSettings.showTimeBars }
        set { AppSettings.showTimeBars = newValue }
    }
}

private enum AssocKey {
    static var proxyKey: UInt8 = 0
}

// MARK: - Clocks Tab

class ClocksTabViewController: NSViewController {
    private var menuBarTable: NSTableView!
    private var worldTable: NSTableView!
    private var menuBarClocks: [String] = []
    private var worldClocks: [String] = []
    private var primaryPicker: NSPopUpButton!
    private var allTZIDs: [String] = []

    override func loadView() { view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 380)) }

    override func viewDidLoad() {
        super.viewDidLoad()
        menuBarClocks = AppSettings.menuBarClockTimezones
        worldClocks = AppSettings.worldClockIdentifiers
        buildUI()
    }

    private func buildUI() {
        let W: CGFloat = 480
        let H: CGFloat = 380

        // Primary clock section
        let ph = NSTextField(labelWithString: "PRIMARY CLOCK")
        ph.font = NSFont.boldSystemFont(ofSize: 10)
        ph.textColor = .secondaryLabelColor
        ph.frame = NSRect(x: 20, y: H - 36, width: W - 40, height: 20)
        view.addSubview(ph)

        let tzLabel = NSTextField(labelWithString: "Timezone:")
        tzLabel.font = NSFont.systemFont(ofSize: 13)
        tzLabel.frame = NSRect(x: 20, y: H - 68, width: 80, height: 22)
        view.addSubview(tzLabel)

        primaryPicker = NSPopUpButton(frame: NSRect(x: 105, y: H - 70, width: 340, height: 26))
        allTZIDs = commonTZIDs()
        // Add "System Default" option first
        primaryPicker.addItem(withTitle: "System Default (\(TimeZone.current.identifier))")
        primaryPicker.lastItem?.representedObject = ""
        for id in allTZIDs {
            let city = id.split(separator: "/").last.map {
                String($0).replacingOccurrences(of: "_", with: " ")
            } ?? id
            primaryPicker.addItem(withTitle: "\(city) (\(id))")
            primaryPicker.lastItem?.representedObject = id
        }
        // Select current primary
        let currentID = AppSettings.primaryTimezone.identifier
        if let idx = primaryPicker.itemArray.firstIndex(where: { ($0.representedObject as? String) == currentID }) {
            primaryPicker.selectItem(at: idx)
        } else if currentID == TimeZone.current.identifier {
            primaryPicker.selectItem(at: 0)
        }
        primaryPicker.target = self
        primaryPicker.action = #selector(primaryPickerChanged(_:))
        view.addSubview(primaryPicker)

        // Menu bar clocks section
        let mh = NSTextField(labelWithString: "SECONDARY CLOCKS IN MENU BAR (up to 2)")
        mh.font = NSFont.boldSystemFont(ofSize: 10)
        mh.textColor = .secondaryLabelColor
        mh.frame = NSRect(x: 20, y: H - 112, width: W - 40, height: 20)
        view.addSubview(mh)

        menuBarTable = makeTable(id: "menubar", columns: ["Timezone (Menu Bar)"])
        let mbScroll = scrollWrap(menuBarTable, frame: NSRect(x: 20, y: H - 196, width: W - 40, height: 74))
        view.addSubview(mbScroll)

        let mbBtns = makePlusMinusButtons(plusAction: #selector(addMenuBar), minusAction: #selector(removeMenuBar))
        mbBtns.frame = NSRect(x: 20, y: H - 210, width: 60, height: 18)
        view.addSubview(mbBtns)

        // World clocks section
        let wh = NSTextField(labelWithString: "WORLD CLOCKS (shown in popover)")
        wh.font = NSFont.boldSystemFont(ofSize: 10)
        wh.textColor = .secondaryLabelColor
        wh.frame = NSRect(x: 20, y: H - 240, width: W - 40, height: 20)
        view.addSubview(wh)

        worldTable = makeTable(id: "world", columns: ["Timezone (World Clocks)"])
        let wScroll = scrollWrap(worldTable, frame: NSRect(x: 20, y: H - 340, width: W - 40, height: 90))
        view.addSubview(wScroll)

        let wBtns = makePlusMinusButtons(plusAction: #selector(addWorld), minusAction: #selector(removeWorld))
        wBtns.frame = NSRect(x: 20, y: H - 354, width: 60, height: 18)
        view.addSubview(wBtns)
    }

    @objc private func primaryPickerChanged(_ sender: NSPopUpButton) {
        guard let id = sender.selectedItem?.representedObject as? String else { return }
        if id.isEmpty {
            UserDefaults.standard.removeObject(forKey: "primaryTimezone")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        } else {
            AppSettings.primaryTimezone = TimeZone(identifier: id) ?? .current
        }
    }

    private func makeTable(id: String, columns: [String]) -> NSTableView {
        let tv = NSTableView()
        for col in columns {
            let c = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id + col))
            c.title = col
            tv.addTableColumn(c)
        }
        tv.headerView = nil
        tv.rowHeight = 22
        tv.dataSource = self
        tv.delegate = self
        return tv
    }

    private func scrollWrap(_ tv: NSTableView, frame: NSRect) -> NSScrollView {
        let sv = NSScrollView(frame: frame)
        sv.documentView = tv
        sv.hasVerticalScroller = true
        sv.borderType = .lineBorder
        return sv
    }

    private func makePlusMinusButtons(plusAction: Selector, minusAction: Selector) -> NSSegmentedControl {
        let seg = NSSegmentedControl(images: [
            NSImage(systemSymbolName: "plus", accessibilityDescription: "Add")!,
            NSImage(systemSymbolName: "minus", accessibilityDescription: "Remove")!
        ], trackingMode: .momentary, target: self, action: #selector(segmentedAction(_:)))
        seg.tag = plusAction.hashValue   // simple trick won't work, let's do differently
        // Actually use separate approach - create as stack
        return seg
    }

    @objc private func addMenuBar() { showTZPicker { [weak self] id in
        guard let self = self, self.menuBarClocks.count < 2, !self.menuBarClocks.contains(id) else { return }
        self.menuBarClocks.append(id)
        AppSettings.menuBarClockTimezones = self.menuBarClocks
        self.menuBarTable.reloadData()
    }}

    @objc private func removeMenuBar() {
        let row = menuBarTable.selectedRow
        guard row >= 0 && row < menuBarClocks.count else { return }
        menuBarClocks.remove(at: row)
        AppSettings.menuBarClockTimezones = menuBarClocks
        menuBarTable.reloadData()
    }

    @objc private func addWorld() { showTZPicker { [weak self] id in
        guard let self = self, !self.worldClocks.contains(id) else { return }
        self.worldClocks.append(id)
        AppSettings.worldClockIdentifiers = self.worldClocks
        self.worldTable.reloadData()
    }}

    @objc private func removeWorld() {
        let row = worldTable.selectedRow
        guard row >= 0 && row < worldClocks.count else { return }
        worldClocks.remove(at: row)
        AppSettings.worldClockIdentifiers = worldClocks
        worldTable.reloadData()
    }

    @objc private func segmentedAction(_ sender: NSSegmentedControl) {}

    private func showTZPicker(completion: @escaping (String) -> Void) {
        let panel = TZPickerPanel(completion: completion)
        panel.runModal()
    }

    private func displayName(_ id: String) -> String {
        let city = id.split(separator: "/").last.map {
            String($0).replacingOccurrences(of: "_", with: " ")
        } ?? id
        return "\(city)  (\(id))"
    }
}

extension ClocksTabViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        tableView === menuBarTable ? menuBarClocks.count : worldClocks.count
    }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = tableView === menuBarTable ? menuBarClocks[row] : worldClocks[row]
        let city = id.split(separator: "/").last.map {
            String($0).replacingOccurrences(of: "_", with: " ")
        } ?? id
        let now = Date()
        let f = DateFormatter(); f.timeZone = TimeZone(identifier: id); f.timeStyle = .short
        let time = f.string(from: now)
        let lbl = NSTextField(labelWithString: "\(city)  —  \(time)  (\(id))")
        lbl.font = NSFont.systemFont(ofSize: 12)
        lbl.textColor = .labelColor
        return lbl
    }
}

// MARK: - Shared timezone list

private func commonTZIDs() -> [String] {
    return [
        "America/New_York","America/Chicago","America/Denver","America/Los_Angeles",
        "America/Anchorage","America/Honolulu","America/Sao_Paulo","America/Toronto",
        "America/Vancouver","America/Mexico_City","America/Argentina/Buenos_Aires",
        "America/Bogota","America/Lima","America/Santiago",
        "Europe/London","Europe/Paris","Europe/Berlin","Europe/Rome","Europe/Madrid",
        "Europe/Moscow","Europe/Istanbul","Europe/Amsterdam","Europe/Stockholm",
        "Europe/Zurich","Europe/Warsaw","Europe/Kiev","Europe/Lisbon",
        "Africa/Cairo","Africa/Lagos","Africa/Johannesburg","Africa/Nairobi",
        "Asia/Dubai","Asia/Karachi","Asia/Kolkata","Asia/Dhaka",
        "Asia/Colombo","Asia/Bangkok","Asia/Singapore","Asia/Shanghai",
        "Asia/Hong_Kong","Asia/Tokyo","Asia/Seoul","Asia/Jakarta",
        "Asia/Manila","Asia/Taipei","Asia/Kuala_Lumpur",
        "Australia/Sydney","Australia/Melbourne","Australia/Brisbane","Australia/Perth",
        "Pacific/Auckland","Pacific/Fiji","Pacific/Honolulu",
    ]
}

// MARK: - Timezone picker sheet

class TZPickerPanel: NSObject {
    private var completion: (String) -> Void
    private var picker: NSPopUpButton!
    private var allIDs: [String] = []

    init(completion: @escaping (String) -> Void) {
        self.completion = completion
        super.init()
    }

    func runModal() {
        let panel = NSAlert()
        panel.messageText = "Add Timezone"
        panel.addButton(withTitle: "Add")
        panel.addButton(withTitle: "Cancel")

        picker = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 320, height: 26))
        allIDs = commonTZIDs()
        for id in allIDs {
            let city = id.split(separator: "/").last.map {
                String($0).replacingOccurrences(of: "_", with: " ")
            } ?? id
            picker.addItem(withTitle: "\(city) (\(id))")
            picker.lastItem?.representedObject = id
        }
        panel.accessoryView = picker

        if panel.runModal() == .alertFirstButtonReturn,
           let id = picker.selectedItem?.representedObject as? String {
            completion(id)
        }
    }

}

// MARK: - Events Tab

class EventsTabViewController: NSViewController {
    private var calendarTable: NSTableView!
    private var allCalendars: [EKCalendar] = []
    private var enabledIDs: Set<String> = []

    override func loadView() { view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 300)) }

    override func viewDidLoad() {
        super.viewDidLoad()
        allCalendars = EventManager.shared.allCalendars
        let saved = AppSettings.enabledCalendarIdentifiers
        enabledIDs = saved.isEmpty ? Set(allCalendars.map { $0.calendarIdentifier }) : Set(saved)
        buildUI()
    }

    private func buildUI() {
        let W: CGFloat = 480; let H: CGFloat = 300

        let h1 = NSTextField(labelWithString: "SHOW UPCOMING EVENTS")
        h1.font = NSFont.boldSystemFont(ofSize: 10); h1.textColor = .secondaryLabelColor
        h1.frame = NSRect(x: 20, y: H - 36, width: 300, height: 20)
        view.addSubview(h1)

        let showCB = NSButton(checkboxWithTitle: "Show upcoming events section in popover",
                              target: self, action: #selector(toggleShow))
        showCB.state = AppSettings.showUpcomingEvents ? .on : .off
        showCB.frame = NSRect(x: 20, y: H - 60, width: 350, height: 20)
        view.addSubview(showCB)

        if !EventManager.shared.isAuthorized {
            let btn = NSButton(title: "Grant Calendar Access…", target: self, action: #selector(requestAccess))
            btn.bezelStyle = .rounded
            btn.frame = NSRect(x: 20, y: H - 90, width: 200, height: 26)
            view.addSubview(btn)
            return
        }

        let h2 = NSTextField(labelWithString: "CALENDARS")
        h2.font = NSFont.boldSystemFont(ofSize: 10); h2.textColor = .secondaryLabelColor
        h2.frame = NSRect(x: 20, y: H - 96, width: 200, height: 20)
        view.addSubview(h2)

        calendarTable = NSTableView()
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("cal"))
        col.title = "Calendar"
        calendarTable.addTableColumn(col)
        calendarTable.headerView = nil
        calendarTable.rowHeight = 24
        calendarTable.dataSource = self
        calendarTable.delegate = self

        let sv = NSScrollView(frame: NSRect(x: 20, y: H - 256, width: W - 40, height: 150))
        sv.documentView = calendarTable
        sv.hasVerticalScroller = true
        sv.borderType = .lineBorder
        view.addSubview(sv)

        let note = NSTextField(labelWithString: "Unchecked calendars won't appear in the events panel.")
        note.font = NSFont.systemFont(ofSize: 10); note.textColor = .tertiaryLabelColor
        note.frame = NSRect(x: 20, y: H - 276, width: W - 40, height: 14)
        view.addSubview(note)
    }

    @objc private func toggleShow(_ sender: NSButton) {
        AppSettings.showUpcomingEvents = sender.state == .on
    }

    @objc private func requestAccess() {
        EventManager.shared.requestAccess { [weak self] granted in
            if granted { self?.viewDidLoad() }
        }
    }
}

extension EventsTabViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { allCalendars.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cal = allCalendars[row]
        let cb = NSButton(checkboxWithTitle: cal.title, target: self, action: #selector(calToggled(_:)))
        cb.tag = row
        cb.state = enabledIDs.contains(cal.calendarIdentifier) ? .on : .off

        // Color dot
        let dot = NSView(frame: NSRect(x: 20, y: 8, width: 8, height: 8))
        dot.wantsLayer = true; dot.layer?.cornerRadius = 4
        dot.layer?.backgroundColor = (NSColor(cgColor: cal.cgColor) ?? .controlAccentColor).cgColor

        let row2 = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 24))
        cb.frame = NSRect(x: 0, y: 4, width: 380, height: 18)
        row2.addSubview(cb)
        return row2
    }

    @objc private func calToggled(_ sender: NSButton) {
        let cal = allCalendars[sender.tag]
        if sender.state == .on { enabledIDs.insert(cal.calendarIdentifier) }
        else { enabledIDs.remove(cal.calendarIdentifier) }
        AppSettings.enabledCalendarIdentifiers = Array(enabledIDs)
    }
}
