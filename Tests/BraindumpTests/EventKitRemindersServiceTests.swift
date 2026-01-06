import Testing
import Foundation
@testable import BraindumpCLI

@Suite("EventKitRemindersService Tests")
struct EventKitRemindersServiceTests {
    
    @Test("Error descriptions are localized correctly")
    func errorDescriptions() {
        let accessDenied = EventKitRemindersError.accessDenied
        #expect(accessDenied.errorDescription == "Access to Reminders was denied")
        
        let listNotFound = EventKitRemindersError.listNotFound("Work")
        #expect(listNotFound.errorDescription == "Reminder list 'Work' not found")
        
        let reminderNotFound = EventKitRemindersError.reminderNotFound("abc123")
        #expect(reminderNotFound.errorDescription == "Reminder with id 'abc123' not found")
        
        let noDefaultCalendar = EventKitRemindersError.noDefaultCalendar
        #expect(noDefaultCalendar.errorDescription == "No default calendar for reminders")
    }
    
    @Test("Service can be initialized")
    func initialization() async {
        let service = EventKitRemindersService()
        _ = service
    }
    
    @Test("Reminder model has correct properties")
    func reminderModel() {
        let dueDate = Date()
        let reminder = Reminder(
            id: "test-id",
            title: "Test Reminder",
            list: "Personal",
            dueDate: dueDate,
            isCompleted: false,
            notes: "Some notes",
            priority: 1
        )
        
        #expect(reminder.id == "test-id")
        #expect(reminder.title == "Test Reminder")
        #expect(reminder.list == "Personal")
        #expect(reminder.dueDate == dueDate)
        #expect(reminder.isCompleted == false)
        #expect(reminder.notes == "Some notes")
        #expect(reminder.priority == 1)
    }
    
    @Test("ReminderList model has correct properties")
    func reminderListModel() {
        let list = ReminderList(name: "Work", count: 5)
        
        #expect(list.name == "Work")
        #expect(list.count == 5)
    }
    
    @Test("Reminder is Codable")
    func reminderCodable() throws {
        let reminder = Reminder(
            id: "123",
            title: "Buy groceries",
            list: "Shopping",
            dueDate: Date(timeIntervalSince1970: 1704067200),
            isCompleted: true,
            notes: "Milk, eggs, bread",
            priority: 2
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(reminder)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Reminder.self, from: data)
        
        #expect(decoded.id == reminder.id)
        #expect(decoded.title == reminder.title)
        #expect(decoded.list == reminder.list)
        #expect(decoded.isCompleted == reminder.isCompleted)
        #expect(decoded.notes == reminder.notes)
        #expect(decoded.priority == reminder.priority)
    }
    
    @Test("ReminderList is Codable")
    func reminderListCodable() throws {
        let list = ReminderList(name: "Work", count: 10)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(list)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ReminderList.self, from: data)
        
        #expect(decoded.name == list.name)
        #expect(decoded.count == list.count)
    }
}
