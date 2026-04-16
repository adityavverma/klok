import Foundation
import EventKit

class EventManager {
    static let shared = EventManager()
    let store = EKEventStore()
    private(set) var isAuthorized = false

    private init() {
        checkStatus()
        NotificationCenter.default.addObserver(
            self, selector: #selector(storeChanged),
            name: .EKEventStoreChanged, object: store
        )
    }

    private func checkStatus() {
        let s = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) {
            isAuthorized = (s == .fullAccess)
        } else {
            isAuthorized = (s == .authorized)
        }
    }

    func requestAccess(completion: @escaping (Bool) -> Void) {
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { [weak self] granted, _ in
                DispatchQueue.main.async { self?.isAuthorized = granted; completion(granted) }
            }
        } else {
            store.requestAccess(to: .event) { [weak self] granted, _ in
                DispatchQueue.main.async { self?.isAuthorized = granted; completion(granted) }
            }
        }
    }

    // Events for a given month (for dot indicators in calendar)
    func eventsForMonth(_ date: Date) -> [EKEvent] {
        guard isAuthorized else { return [] }
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month], from: date)
        comps.day = 1
        guard let start = cal.date(from: comps),
              let end = cal.date(byAdding: .month, value: 1, to: start) else { return [] }
        let cals = filteredCalendars()
        let pred = store.predicateForEvents(withStart: start, end: end,
                                             calendars: cals.isEmpty ? nil : cals)
        return store.events(matching: pred).sorted { $0.startDate < $1.startDate }
    }

    // Upcoming events within the next N days
    func upcomingEvents(days: Int = 7, max: Int = 5) -> [EKEvent] {
        guard isAuthorized else { return [] }
        let now = Date()
        guard let end = Calendar.current.date(byAdding: .day, value: days, to: now) else { return [] }
        let cals = filteredCalendars()
        let pred = store.predicateForEvents(withStart: now, end: end,
                                             calendars: cals.isEmpty ? nil : cals)
        return Array(store.events(matching: pred)
            .filter { !$0.isAllDay || $0.startDate >= now }
            .sorted { $0.startDate < $1.startDate }
            .prefix(max))
    }

    func nextEvent() -> EKEvent? { upcomingEvents(days: 2, max: 1).first }

    var allCalendars: [EKCalendar] { store.calendars(for: .event) }

    private func filteredCalendars() -> [EKCalendar] {
        let ids = AppSettings.enabledCalendarIdentifiers
        guard !ids.isEmpty else { return [] }
        return allCalendars.filter { ids.contains($0.calendarIdentifier) }
    }

    @objc private func storeChanged() {
        checkStatus()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .eventsChanged, object: nil)
        }
    }
}

extension Notification.Name {
    static let eventsChanged = Notification.Name("KlokEventsChanged")
}
