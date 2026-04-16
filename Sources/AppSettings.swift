import Foundation

struct AppSettings {

    // MARK: - Menu Bar
    // nil = system local timezone
    static var primaryTimezone: TimeZone {
        get {
            if let id = UserDefaults.standard.string(forKey: "primaryTimezone"),
               let tz = TimeZone(identifier: id) { return tz }
            return .current
        }
        set { set("primaryTimezone", newValue.identifier) }
    }

    static var showDate: Bool {
        get { UserDefaults.standard.object(forKey: "showDate") as? Bool ?? true }
        set { set("showDate", newValue) }
    }
    static var use24HourFormat: Bool {
        get { UserDefaults.standard.bool(forKey: "use24HourFormat") }
        set { set("use24HourFormat", newValue) }
    }
    static var showSeconds: Bool {
        get { UserDefaults.standard.bool(forKey: "showSeconds") }
        set { set("showSeconds", newValue) }
    }
    static var showNextEventInMenuBar: Bool {
        get { UserDefaults.standard.bool(forKey: "showNextEventInMenuBar") }
        set { set("showNextEventInMenuBar", newValue) }
    }
    // Up to 2 secondary timezone IDs shown in menu bar
    static var menuBarClockTimezones: [String] {
        get { UserDefaults.standard.stringArray(forKey: "menuBarClockTimezones") ?? ["America/New_York"] }
        set { set("menuBarClockTimezones", newValue) }
    }
    static var showSecondaryInMenuBar: Bool {
        get { UserDefaults.standard.object(forKey: "showSecondaryInMenuBar") as? Bool ?? true }
        set { set("showSecondaryInMenuBar", newValue) }
    }

    // MARK: - Calendar View
    static var weekStartsOnMonday: Bool {
        get { UserDefaults.standard.bool(forKey: "weekStartsOnMonday") }
        set { set("weekStartsOnMonday", newValue) }
    }
    static var showWeekNumbers: Bool {
        get { UserDefaults.standard.object(forKey: "showWeekNumbers") as? Bool ?? true }
        set { set("showWeekNumbers", newValue) }
    }
    static var highlightWeekends: Bool {
        get { UserDefaults.standard.object(forKey: "highlightWeekends") as? Bool ?? true }
        set { set("highlightWeekends", newValue) }
    }
    static var showEventDotsInCalendar: Bool {
        get { UserDefaults.standard.object(forKey: "showEventDotsInCalendar") as? Bool ?? true }
        set { set("showEventDotsInCalendar", newValue) }
    }

    // MARK: - Events
    static var showUpcomingEvents: Bool {
        get { UserDefaults.standard.object(forKey: "showUpcomingEvents") as? Bool ?? true }
        set { set("showUpcomingEvents", newValue) }
    }
    static var enabledCalendarIdentifiers: [String] {
        get { UserDefaults.standard.stringArray(forKey: "enabledCalendarIdentifiers") ?? [] }
        set { set("enabledCalendarIdentifiers", newValue) }
    }

    // MARK: - World Clocks
    static var worldClockIdentifiers: [String] {
        get { UserDefaults.standard.stringArray(forKey: "worldClockIdentifiers")
              ?? ["America/New_York", "Europe/London", "Asia/Tokyo"] }
        set { set("worldClockIdentifiers", newValue) }
    }
    static var showTimeBars: Bool {
        get { UserDefaults.standard.object(forKey: "showTimeBars") as? Bool ?? true }
        set { set("showTimeBars", newValue) }
    }

    // MARK: - Helpers
    private static func set(_ key: String, _ value: Any) {
        UserDefaults.standard.set(value, forKey: key)
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }
}

extension Notification.Name {
    static let settingsChanged = Notification.Name("KlokSettingsChanged")
}
