import AppKit
import Foundation

// No section header, just clean rows — matches Dato style
class WorldClocksView: NSView {
    private var rows: [ClockRow] = []
    let rowH: CGFloat = 48

    override init(frame: NSRect) {
        super.init(frame: frame)
        buildRows()
        NotificationCenter.default.addObserver(self, selector: #selector(onSettings),
                                               name: .settingsChanged, object: nil)
    }
    required init?(coder: NSCoder) { fatalError() }
    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func onSettings() { buildRows() }

    func buildRows() {
        subviews.forEach { $0.removeFromSuperview() }
        rows.removeAll()
        let ids = AppSettings.worldClockIdentifiers.prefix(4)
        for (i, id) in ids.enumerated() {
            guard let tz = TimeZone(identifier: id) else { continue }
            let row = ClockRow(
                frame: NSRect(x: 0, y: bounds.height - CGFloat(i + 1) * rowH,
                              width: bounds.width, height: rowH),
                timezone: tz,
                displayName: cityName(id)
            )
            addSubview(row)
            rows.append(row)
        }
    }

    func tick() { rows.forEach { $0.updateTime() } }
    func refresh() { buildRows() }

    private func cityName(_ id: String) -> String {
        (id.split(separator: "/").last.map { String($0).replacingOccurrences(of: "_", with: " ") }) ?? id
    }
}

// MARK: - Single clock row

class ClockRow: NSView {
    private let tz: TimeZone
    private let name: String
    private var iconView: NSImageView!
    private var nameLabel: NSTextField!
    private var offsetLabel: NSTextField!
    private var timeLabel: NSTextField!
    private var dayLabel: NSTextField!

    init(frame: NSRect, timezone: TimeZone, displayName: String) {
        self.tz = timezone; self.name = displayName
        super.init(frame: frame)
        buildUI()
        updateTime()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        // Top hairline separator
        let sep = NSView(frame: NSRect(x: 16, y: bounds.height - 1, width: bounds.width - 32, height: 1))
        sep.wantsLayer = true
        sep.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
        addSubview(sep)

        // Day/night icon (SF Symbol)
        iconView = NSImageView(frame: NSRect(x: 16, y: (bounds.height - 14) / 2, width: 14, height: 14))
        iconView.contentTintColor = .secondaryLabelColor
        addSubview(iconView)

        // City name
        nameLabel = NSTextField(labelWithString: name)
        nameLabel.font = NSFont.systemFont(ofSize: 13)
        nameLabel.textColor = .labelColor
        nameLabel.frame = NSRect(x: 36, y: bounds.height / 2 + 1, width: 130, height: 16)
        addSubview(nameLabel)

        // UTC offset
        offsetLabel = NSTextField(labelWithString: "")
        offsetLabel.font = NSFont.systemFont(ofSize: 10.5)
        offsetLabel.textColor = .tertiaryLabelColor
        offsetLabel.frame = NSRect(x: 36, y: bounds.height / 2 - 14, width: 130, height: 14)
        addSubview(offsetLabel)

        // Time (right side, large)
        timeLabel = NSTextField(labelWithString: "")
        timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 17, weight: .regular)
        timeLabel.textColor = .labelColor
        timeLabel.alignment = .right
        timeLabel.frame = NSRect(x: bounds.width - 140, y: bounds.height / 2, width: 124, height: 20)
        addSubview(timeLabel)

        // Day (right side, small — "Wed, Today")
        dayLabel = NSTextField(labelWithString: "")
        dayLabel.font = NSFont.systemFont(ofSize: 10.5)
        dayLabel.textColor = .tertiaryLabelColor
        dayLabel.alignment = .right
        dayLabel.frame = NSRect(x: bounds.width - 140, y: bounds.height / 2 - 14, width: 124, height: 14)
        addSubview(dayLabel)
    }

    func updateTime() {
        let now = Date()

        // Time string
        let f = DateFormatter()
        f.timeZone = tz
        f.dateFormat = AppSettings.use24HourFormat ? "HH:mm" : "h:mm a"
        timeLabel.stringValue = f.string(from: now)

        // Offset
        let diff = tz.secondsFromGMT(for: now) - TimeZone.current.secondsFromGMT(for: now)
        if diff == 0 {
            offsetLabel.stringValue = "Same as local"
        } else {
            let sign = diff > 0 ? "+" : "-"
            let h = abs(diff) / 3600; let m = (abs(diff) % 3600) / 60
            offsetLabel.stringValue = m == 0 ? "\(sign)\(h)h" : "\(sign)\(h)h \(m)m"
        }

        // Day/night icon
        var tzCal = Calendar.current; tzCal.timeZone = tz
        let hour = tzCal.component(.hour, from: now)
        let isDaytime = hour >= 6 && hour < 20
        let symbolName = isDaytime ? "sun.min.fill" : "moon.fill"
        iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        iconView.contentTintColor = isDaytime
            ? NSColor.systemYellow.withAlphaComponent(0.85)
            : NSColor.systemIndigo.withAlphaComponent(0.8)

        // "Wed, Today/Tomorrow/..."
        dayLabel.stringValue = relativeDayString(in: tz, now: now)
    }

    private func relativeDayString(in tz: TimeZone, now: Date) -> String {
        var tzCal = Calendar.current; tzCal.timeZone = tz
        var localCal = Calendar.current; localCal.timeZone = .current

        let df = DateFormatter(); df.timeZone = tz; df.dateFormat = "EEE"
        let dow = df.string(from: now)

        let localOrd = localCal.ordinality(of: .day, in: .era, for: now) ?? 0
        let tzOrd = tzCal.ordinality(of: .day, in: .era, for: now) ?? 0

        let rel: String
        switch tzOrd - localOrd {
        case 0:  rel = "Today"
        case 1:  rel = "Tomorrow"
        case -1: rel = "Yesterday"
        default:
            df.dateFormat = "d MMM"; rel = df.string(from: now)
            return "\(dow), \(rel)"
        }
        return "\(dow), \(rel)"
    }
}
