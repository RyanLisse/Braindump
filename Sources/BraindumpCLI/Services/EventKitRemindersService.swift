import EventKit
import Foundation

public actor EventKitRemindersService: RemindersServiceProtocol {
    private let eventStore: EKEventStore
    
    public init() {
        self.eventStore = EKEventStore()
    }
    
    private func requestAccess() async throws {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        switch status {
        case .authorized, .fullAccess:
            return
        case .notDetermined:
            let granted = try await eventStore.requestFullAccessToReminders()
            guard granted else {
                throw EventKitRemindersError.accessDenied
            }
        case .denied, .restricted, .writeOnly:
            throw EventKitRemindersError.accessDenied
        @unknown default:
            throw EventKitRemindersError.accessDenied
        }
    }
    
    public func listLists() async throws -> [ReminderList] {
        try await requestAccess()
        let calendars = eventStore.calendars(for: .reminder)
        return calendars.map { calendar in
            let predicate = eventStore.predicateForIncompleteReminders(
                withDueDateStarting: nil,
                ending: nil,
                calendars: [calendar]
            )
            var count = 0
            let semaphore = DispatchSemaphore(value: 0)
            eventStore.fetchReminders(matching: predicate) { reminders in
                count = reminders?.count ?? 0
                semaphore.signal()
            }
            semaphore.wait()
            return ReminderList(name: calendar.title, count: count)
        }
    }
    
    public func listReminders(list: String?, includeCompleted: Bool) async throws -> [Reminder] {
        try await requestAccess()
        
        var calendars: [EKCalendar]? = nil
        if let listName = list {
            guard let calendar = eventStore.calendars(for: .reminder).first(where: { $0.title == listName }) else {
                throw EventKitRemindersError.listNotFound(listName)
            }
            calendars = [calendar]
        }
        
        let predicate: NSPredicate
        if includeCompleted {
            predicate = eventStore.predicateForReminders(in: calendars)
        } else {
            predicate = eventStore.predicateForIncompleteReminders(
                withDueDateStarting: nil,
                ending: nil,
                calendars: calendars
            )
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { ekReminders in
                let reminders = (ekReminders ?? []).map { self.mapReminder($0) }
                continuation.resume(returning: reminders)
            }
        }
    }
    
    public func createReminder(title: String, list: String, dueDate: Date?, notes: String?, priority: Int) async throws -> String {
        try await requestAccess()
        
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.notes = notes
        reminder.priority = priority
        
        guard let calendar = eventStore.calendars(for: .reminder).first(where: { $0.title == list }) else {
            throw EventKitRemindersError.listNotFound(list)
        }
        reminder.calendar = calendar
        
        if let dueDate = dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )
        }
        
        try eventStore.save(reminder, commit: true)
        return reminder.calendarItemIdentifier
    }
    
    public func getReminder(id: String) async throws -> Reminder? {
        try await requestAccess()
        
        guard let ekReminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            return nil
        }
        
        return mapReminder(ekReminder)
    }
    
    public func completeReminder(id: String) async throws {
        try await requestAccess()
        
        guard let reminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw EventKitRemindersError.reminderNotFound(id)
        }
        
        reminder.isCompleted = true
        try eventStore.save(reminder, commit: true)
    }
    
    public func uncompleteReminder(id: String) async throws {
        try await requestAccess()
        
        guard let reminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw EventKitRemindersError.reminderNotFound(id)
        }
        
        reminder.isCompleted = false
        try eventStore.save(reminder, commit: true)
    }
    
    public func deleteReminder(id: String) async throws {
        try await requestAccess()
        
        guard let reminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw EventKitRemindersError.reminderNotFound(id)
        }
        
        try eventStore.remove(reminder, commit: true)
    }
    
    public func searchReminders(query: String) async throws -> [Reminder] {
        try await requestAccess()
        
        let predicate = eventStore.predicateForReminders(in: nil)
        
        return try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { ekReminders in
                let lowercaseQuery = query.lowercased()
                let filtered = (ekReminders ?? []).filter { reminder in
                    let titleMatch = reminder.title?.lowercased().contains(lowercaseQuery) ?? false
                    let notesMatch = reminder.notes?.lowercased().contains(lowercaseQuery) ?? false
                    return titleMatch || notesMatch
                }
                let reminders = filtered.map { self.mapReminder($0) }
                continuation.resume(returning: reminders)
            }
        }
    }
    
    private nonisolated func mapReminder(_ ekReminder: EKReminder) -> Reminder {
        var dueDate: Date? = nil
        if let components = ekReminder.dueDateComponents {
            dueDate = Calendar.current.date(from: components)
        }
        
        return Reminder(
            id: ekReminder.calendarItemIdentifier,
            title: ekReminder.title ?? "",
            list: ekReminder.calendar?.title ?? "",
            dueDate: dueDate,
            isCompleted: ekReminder.isCompleted,
            notes: ekReminder.notes,
            priority: Int(ekReminder.priority)
        )
    }
}

public enum EventKitRemindersError: Error, LocalizedError {
    case accessDenied
    case listNotFound(String)
    case reminderNotFound(String)
    case noDefaultCalendar
    
    public var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Access to Reminders was denied"
        case .listNotFound(let name):
            return "Reminder list '\(name)' not found"
        case .reminderNotFound(let id):
            return "Reminder with id '\(id)' not found"
        case .noDefaultCalendar:
            return "No default calendar for reminders"
        }
    }
}
