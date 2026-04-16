import AppKit
import EventKit
import Foundation

// No section header label — events flow directly like in Dato
class UpcomingEventsView: NSView {
    let rowH: CGFloat = 52

    override init(frame: NSRect) {
        super.init(frame: frame)
        buildUI()
        NotificationCenter.default.addObserver(self, selector: #selector(reload),
                                               name: .eventsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reload),
                                               name: .settingsChanged, object: nil)
    }
    required init?(coder: NSCoder) { fatalError() }
    deinit { NotificationCenter.default.removeObserver(self) }

    @objc func reload() { buildUI() }

    private func buildUI() {
        subviews.forEach { $0.removeFromSuperview() }

        guard EventManager.shared.isAuthorized else {
            let btn = NSButton(title: "Grant Calendar Access…",
                               target: self, action: #selector(requestAccess))
            btn.bezelStyle = .rounded
            btn.font = NSFont.systemFont(ofSize: 11)
            btn.frame = NSRect(x: bounds.width / 2 - 100, y: (bounds.height - 26) / 2,
                               width: 200, height: 26)
            addSubview(btn)
            return
        }

        let maxEvents = Int(bounds.height / rowH)
        let events = EventManager.shared.upcomingEvents(days: 7, max: maxEvents)

        if events.isEmpty {
            let lbl = NSTextField(labelWithString: "No upcoming events")
            lbl.font = NSFont.systemFont(ofSize: 12); lbl.textColor = .tertiaryLabelColor
            lbl.alignment = .center
            lbl.frame = NSRect(x: 0, y: (bounds.height - 20) / 2, width: bounds.width, height: 20)
            addSubview(lbl)
        } else {
            for (i, event) in events.enumerated() {
                let row = EventRow(
                    frame: NSRect(x: 0,
                                  y: bounds.height - CGFloat(i + 1) * rowH,
                                  width: bounds.width, height: rowH),
                    event: event
                )
                addSubview(row)
            }
        }
    }

    @objc private func requestAccess() {
        EventManager.shared.requestAccess { [weak self] _ in self?.buildUI() }
    }
}

// MARK: - Event row with left color bar (Dato style)

class EventRow: NSView {
    init(frame: NSRect, event: EKEvent) {
        super.init(frame: frame)
        build(event: event)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build(event: EKEvent) {
        // Top hairline separator
        let sep = NSView(frame: NSRect(x: 16, y: bounds.height - 1,
                                       width: bounds.width - 32, height: 1))
        sep.wantsLayer = true
        sep.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
        addSubview(sep)

        // Left colored bar (calendar color) — Dato's signature style
        let barColor = NSColor(cgColor: event.calendar.cgColor) ?? .controlAccentColor
        let bar = NSView(frame: NSRect(x: 16, y: 10, width: 3, height: bounds.height - 20))
        bar.wantsLayer = true
        bar.layer?.cornerRadius = 1.5
        bar.layer?.backgroundColor = barColor.cgColor
        addSubview(bar)

        let contentX: CGFloat = 26
        let contentW = bounds.width - contentX - 90

        // Event title
        let title = NSTextField(labelWithString: event.title ?? "Untitled")
        title.font = NSFont.systemFont(ofSize: 12.5, weight: .medium)
        title.textColor = .labelColor
        title.lineBreakMode = .byTruncatingTail
        title.frame = NSRect(x: contentX, y: bounds.height / 2 + 1,
                              width: contentW, height: 15)
        addSubview(title)

        // Time range
        let timeStr = eventTimeString(event)
        let timeLbl = NSTextField(labelWithString: timeStr)
        timeLbl.font = NSFont.systemFont(ofSize: 11)
        timeLbl.textColor = .secondaryLabelColor
        timeLbl.frame = NSRect(x: contentX, y: bounds.height / 2 - 14,
                                width: contentW, height: 14)
        addSubview(timeLbl)

        // Countdown badge (right side)
        let cd = countdownString(event)
        if !cd.isEmpty {
            let cdLbl = NSTextField(labelWithString: cd)
            cdLbl.font = NSFont.systemFont(ofSize: 11)
            cdLbl.textColor = countdownColor(event)
            cdLbl.alignment = .right
            cdLbl.frame = NSRect(x: bounds.width - 82, y: (bounds.height - 14) / 2,
                                  width: 66, height: 14)
            addSubview(cdLbl)
        }

        // Video call icon (if URL present)
        if hasVideoLink(event) {
            let img = NSImageView(frame: NSRect(x: bounds.width - 26,
                                                y: (bounds.height - 14) / 2, width: 14, height: 14))
            img.image = NSImage(systemSymbolName: "video.fill", accessibilityDescription: "Video call")
            img.contentTintColor = barColor
            addSubview(img)
        }
    }

    private func eventTimeString(_ event: EKEvent) -> String {
        if event.isAllDay { return "All day" }
        let f = DateFormatter(); f.timeZone = .current
        f.dateFormat = AppSettings.use24HourFormat ? "HH:mm" : "h:mm a"
        let start = f.string(from: event.startDate)
        let end = f.string(from: event.endDate)
        let cal = Calendar.current
        if cal.isDateInToday(event.startDate) {
            return "\(start) – \(end)"
        } else if cal.isDateInTomorrow(event.startDate) {
            return "Tomorrow · \(start)"
        } else {
            f.dateFormat = AppSettings.use24HourFormat ? "EEE d · HH:mm" : "EEE d · h:mm a"
            return f.string(from: event.startDate)
        }
    }

    private func countdownString(_ event: EKEvent) -> String {
        guard !event.isAllDay else { return "" }
        let diff = event.startDate.timeIntervalSince(Date())
        if diff < 0 { return "now" }
        if diff < 60 { return "< 1m" }
        let mins = Int(diff / 60)
        if mins < 60 { return "in \(mins)m" }
        let hrs = mins / 60; let rem = mins % 60
        return rem == 0 ? "in \(hrs)h" : "in \(hrs)h \(rem)m"
    }

    private func countdownColor(_ event: EKEvent) -> NSColor {
        let diff = event.startDate.timeIntervalSince(Date())
        if diff < 900 { return .systemRed }
        if diff < 3600 { return .systemOrange }
        return .secondaryLabelColor
    }

    private func hasVideoLink(_ event: EKEvent) -> Bool {
        let notes = event.notes ?? ""
        let url = event.url?.absoluteString ?? ""
        let haystack = (notes + url).lowercased()
        return haystack.contains("zoom.us") || haystack.contains("meet.google") ||
               haystack.contains("teams.microsoft") || haystack.contains("webex") ||
               haystack.contains("meet.") || haystack.contains("whereby")
    }
}
