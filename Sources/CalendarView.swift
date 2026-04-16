import AppKit
import Foundation

class CalendarView: NSView {
    private var cal = Calendar.current
    private var displayMonth: Date
    private var today: Date
    // day-of-month → array of calendar colors for that day
    private var eventColorsByDay: [Int: [NSColor]] = [:]

    private let headerH: CGFloat = 38
    private let weekdayH: CGFloat = 22
    private let cellH: CGFloat = 35
    private let weekNumW: CGFloat = 22
    private var cellW: CGFloat = 0

    override init(frame: NSRect) {
        var comps = Calendar.current.dateComponents([.year, .month], from: Date())
        comps.day = 1
        displayMonth = Calendar.current.date(from: comps)!
        today = Calendar.current.startOfDay(for: Date())
        super.init(frame: frame)
        applyWeekStart()
        reloadEventColors()
        buildCalendar()
        NotificationCenter.default.addObserver(self, selector: #selector(onSettings),
                                               name: .settingsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onEvents),
                                               name: .eventsChanged, object: nil)
    }
    required init?(coder: NSCoder) { fatalError() }
    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func onSettings() { applyWeekStart(); buildCalendar() }
    @objc private func onEvents() { reloadEventColors(); buildCalendar() }

    func refresh() {
        today = cal.startOfDay(for: Date())
        applyWeekStart()
        reloadEventColors()
        buildCalendar()
    }

    private func applyWeekStart() {
        var c = Calendar.current
        c.firstWeekday = AppSettings.weekStartsOnMonday ? 2 : 1
        cal = c
    }

    private func reloadEventColors() {
        var map: [Int: [NSColor]] = [:]
        for event in EventManager.shared.eventsForMonth(displayMonth) {
            let day = cal.component(.day, from: event.startDate)
            let color = NSColor(cgColor: event.calendar.cgColor) ?? .controlAccentColor
            if map[day] == nil { map[day] = [] }
            if (map[day]?.count ?? 0) < 3 { map[day]?.append(color) }
        }
        eventColorsByDay = map
    }

    func buildCalendar() {
        subviews.forEach { $0.removeFromSuperview() }

        let showWN = AppSettings.showWeekNumbers
        let leftPad: CGFloat = 16
        let rightPad: CGFloat = 16
        let available = bounds.width - leftPad - rightPad - (showWN ? weekNumW + 4 : 0)
        cellW = floor(available / 7)
        let gridLeft = leftPad + (showWN ? weekNumW + 4 : 0)

        buildHeader(leftPad: leftPad)
        buildWeekdayRow(gridLeft: gridLeft, leftPad: leftPad, showWN: showWN)
        buildGrid(gridLeft: gridLeft, showWN: showWN, leftPad: leftPad)
    }

    // MARK: - Header  (Month left-aligned, arrows on right — matches Dato)

    private func buildHeader(leftPad: CGFloat) {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        let title = NSTextField(labelWithString: fmt.string(from: displayMonth))
        title.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        title.textColor = .labelColor
        title.frame = NSRect(x: leftPad, y: bounds.height - headerH,
                              width: bounds.width - leftPad - 72, height: headerH)
        addSubview(title)

        // Today button (pill style, shown only when navigated away)
        if !cal.isDate(displayMonth, equalTo: today, toGranularity: .month) {
            let todayBtn = NSButton(title: "Today", target: self, action: #selector(goToToday))
            todayBtn.bezelStyle = .rounded
            todayBtn.controlSize = .small
            todayBtn.font = NSFont.systemFont(ofSize: 11)
            todayBtn.frame = NSRect(x: bounds.width - 118, y: bounds.height - headerH + 9,
                                     width: 48, height: 20)
            addSubview(todayBtn)
        }

        // Arrows on right
        let next = arrowBtn("›", action: #selector(nextMonth))
        next.frame = NSRect(x: bounds.width - 16 - 22, y: bounds.height - headerH + 6,
                             width: 22, height: headerH - 12)
        addSubview(next)

        let prev = arrowBtn("‹", action: #selector(prevMonth))
        prev.frame = NSRect(x: bounds.width - 16 - 46, y: bounds.height - headerH + 6,
                             width: 22, height: headerH - 12)
        addSubview(prev)
    }

    // MARK: - Weekday row  (single letters)

    private func buildWeekdayRow(gridLeft: CGFloat, leftPad: CGFloat, showWN: Bool) {
        let y = bounds.height - headerH - weekdayH

        if showWN {
            // "W" label above week numbers column
            let wl = NSTextField(labelWithString: "W")
            wl.font = NSFont.systemFont(ofSize: 9, weight: .regular)
            wl.textColor = .quaternaryLabelColor
            wl.alignment = .right
            wl.frame = NSRect(x: leftPad, y: y, width: weekNumW, height: weekdayH)
            addSubview(wl)
        }

        for (i, name) in weekdayLetters().enumerated() {
            let lbl = NSTextField(labelWithString: name)
            lbl.font = NSFont.systemFont(ofSize: 11, weight: .regular)
            let isWE = AppSettings.highlightWeekends && isWeekendCol(i)
            lbl.textColor = isWE ? NSColor.systemRed.withAlphaComponent(0.6) : .tertiaryLabelColor
            lbl.alignment = .center
            lbl.frame = NSRect(x: gridLeft + CGFloat(i) * cellW, y: y, width: cellW, height: weekdayH)
            addSubview(lbl)
        }
    }

    // MARK: - Grid

    private func buildGrid(gridLeft: CGFloat, showWN: Bool, leftPad: CGFloat) {
        let firstWD = cal.component(.weekday, from: displayMonth)  // 1=Sun
        let offset = weekdayOffset(firstWD)
        let daysInMonth = cal.range(of: .day, in: .month, for: displayMonth)!.count
        let prevMonth = cal.date(byAdding: .month, value: -1, to: displayMonth)!
        let daysInPrev = cal.range(of: .day, in: .month, for: prevMonth)!.count

        let totalCells = offset + daysInMonth
        let rows = Int(ceil(Double(totalCells) / 7.0))
        let topY = bounds.height - headerH - weekdayH - cellH
        var nextDay = 1

        for row in 0..<rows {
            // Week number
            if showWN {
                let firstCellIdx = row * 7 - offset + 1
                let dayForWN = max(1, min(daysInMonth, firstCellIdx))
                var wc = cal.dateComponents([.year, .month], from: displayMonth)
                wc.day = dayForWN
                if let wd = cal.date(from: wc) {
                    let wn = cal.component(.weekOfYear, from: wd)
                    let wnLbl = NSTextField(labelWithString: "\(wn)")
                    wnLbl.font = NSFont.systemFont(ofSize: 9.5)
                    wnLbl.textColor = .quaternaryLabelColor
                    wnLbl.alignment = .right
                    wnLbl.frame = NSRect(x: leftPad, y: topY - CGFloat(row) * cellH,
                                         width: weekNumW, height: cellH)
                    addSubview(wnLbl)
                }
            }

            for col in 0..<7 {
                let idx = row * 7 + col
                var dayNum = 0; var isCurrent = true

                if idx < offset {
                    dayNum = daysInPrev - offset + idx + 1; isCurrent = false
                } else if idx - offset < daysInMonth {
                    dayNum = idx - offset + 1
                } else {
                    dayNum = nextDay; nextDay += 1; isCurrent = false
                }

                var isToday = false
                var colors: [NSColor] = []
                if isCurrent {
                    var dc = cal.dateComponents([.year, .month], from: displayMonth)
                    dc.day = dayNum
                    if let d = cal.date(from: dc) {
                        isToday = cal.isDate(d, inSameDayAs: today)
                        colors = AppSettings.showEventDotsInCalendar ? (eventColorsByDay[dayNum] ?? []) : []
                    }
                }

                let cell = DayCell(
                    frame: NSRect(x: gridLeft + CGFloat(col) * cellW,
                                  y: topY - CGFloat(row) * cellH,
                                  width: cellW, height: cellH),
                    day: dayNum, isToday: isToday,
                    isCurrentMonth: isCurrent,
                    isWeekend: AppSettings.highlightWeekends && isWeekendCol(col),
                    eventColors: colors
                )
                addSubview(cell)
            }
        }
    }

    // MARK: - Actions

    @objc private func prevMonth() {
        displayMonth = cal.date(byAdding: .month, value: -1, to: displayMonth)!
        reloadEventColors(); buildCalendar()
    }
    @objc private func nextMonth() {
        displayMonth = cal.date(byAdding: .month, value: 1, to: displayMonth)!
        reloadEventColors(); buildCalendar()
    }
    @objc private func goToToday() {
        var c = cal.dateComponents([.year, .month], from: Date()); c.day = 1
        displayMonth = cal.date(from: c)!
        reloadEventColors(); buildCalendar()
    }

    // MARK: - Helpers

    private func weekdayLetters() -> [String] {
        let all = ["M", "T", "W", "T", "F", "S", "S"]   // Mon-start
        let sun = ["S", "M", "T", "W", "T", "F", "S"]   // Sun-start
        return AppSettings.weekStartsOnMonday ? all : sun
    }
    private func isWeekendCol(_ col: Int) -> Bool {
        AppSettings.weekStartsOnMonday ? (col == 5 || col == 6) : (col == 0 || col == 6)
    }
    private func weekdayOffset(_ wd: Int) -> Int {
        AppSettings.weekStartsOnMonday ? (wd + 5) % 7 : wd - 1
    }
    private func arrowBtn(_ t: String, action: Selector) -> NSButton {
        let b = NSButton(title: t, target: self, action: action)
        b.bezelStyle = .rounded; b.isBordered = false
        b.font = NSFont.systemFont(ofSize: 16, weight: .light)
        b.contentTintColor = .secondaryLabelColor
        return b
    }
}

// MARK: - Day Cell

class DayCell: NSView {
    init(frame: NSRect, day: Int, isToday: Bool, isCurrentMonth: Bool,
         isWeekend: Bool, eventColors: [NSColor]) {
        super.init(frame: frame)
        wantsLayer = true
        build(day: day, isToday: isToday, isCurrentMonth: isCurrentMonth,
              isWeekend: isWeekend, eventColors: eventColors)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build(day: Int, isToday: Bool, isCurrentMonth: Bool,
                       isWeekend: Bool, eventColors: [NSColor]) {
        let hasEvents = !eventColors.isEmpty
        let circleDiam: CGFloat = min(bounds.height - 10, bounds.width - 6)
        let cx = (bounds.width - circleDiam) / 2
        // Shift day number up a bit if we need space for dots
        let dotAreaH: CGFloat = hasEvents ? 7 : 0
        let labelY = dotAreaH + 1
        let cy = labelY + (bounds.height - labelY - circleDiam) / 2

        if isToday {
            let circle = CALayer()
            circle.frame = CGRect(x: cx, y: cy, width: circleDiam, height: circleDiam)
            circle.cornerRadius = circleDiam / 2
            circle.backgroundColor = NSColor.controlAccentColor.cgColor
            layer?.addSublayer(circle)
        }

        let lbl = NSTextField(labelWithString: "\(day)")
        lbl.font = NSFont.monospacedDigitSystemFont(ofSize: 12.5,
                                                     weight: isToday ? .semibold : .regular)
        lbl.alignment = .center
        if isToday {
            lbl.textColor = .white
        } else if !isCurrentMonth {
            lbl.textColor = .quaternaryLabelColor
        } else if isWeekend {
            lbl.textColor = NSColor.systemRed.withAlphaComponent(0.8)
        } else {
            lbl.textColor = .labelColor
        }
        lbl.frame = NSRect(x: 0, y: dotAreaH, width: bounds.width, height: bounds.height - dotAreaH)
        addSubview(lbl)

        // Colored event dots at bottom (up to 3, in calendar colors)
        if hasEvents && isCurrentMonth {
            let dotD: CGFloat = 4
            let spacing: CGFloat = 3
            let total = CGFloat(eventColors.count) * dotD + CGFloat(eventColors.count - 1) * spacing
            let startX = (bounds.width - total) / 2
            for (i, color) in eventColors.enumerated() {
                let dotX = startX + CGFloat(i) * (dotD + spacing)
                let dot = NSView(frame: NSRect(x: dotX, y: 1.5, width: dotD, height: dotD))
                dot.wantsLayer = true
                dot.layer?.cornerRadius = dotD / 2
                dot.layer?.backgroundColor = isToday
                    ? NSColor.white.withAlphaComponent(0.85).cgColor
                    : color.withAlphaComponent(0.9).cgColor
                addSubview(dot)
            }
        }
    }
}
