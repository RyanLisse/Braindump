import Testing
import Foundation
@testable import BraindumpCLI

@Suite("RemindersService Tests")
struct RemindersServiceTests {
    
    @Test("listLists parses pipe-delimited output correctly")
    func listListsParsesOutput() async throws {
        let mockExecutor = MockAppleScriptExecutor()
        await mockExecutor.setMockResult("Reminders|5\nWork|12\nShopping|3\n")
        
        let service = RemindersService(executor: mockExecutor)
        let lists = try await service.listLists()
        
        #expect(lists.count == 3)
        #expect(lists[0].name == "Reminders")
        #expect(lists[0].count == 5)
        #expect(lists[1].name == "Work")
        #expect(lists[1].count == 12)
    }
    
    @Test("listReminders parses pipe-delimited output correctly")
    func listRemindersParsesOutput() async throws {
        let mockExecutor = MockAppleScriptExecutor()
        await mockExecutor.setMockResult("id123|Reminders|Buy milk|2026-01-10T09:00:00|false|0\nid456|Work|Call client|none|false|1\n")
        
        let service = RemindersService(executor: mockExecutor)
        let reminders = try await service.listReminders(list: nil, includeCompleted: false)
        
        #expect(reminders.count == 2)
        #expect(reminders[0].id == "id123")
        #expect(reminders[0].list == "Reminders")
        #expect(reminders[0].title == "Buy milk")
        #expect(reminders[0].isCompleted == false)
        #expect(reminders[1].id == "id456")
        #expect(reminders[1].title == "Call client")
        #expect(reminders[1].dueDate == nil)
    }
    
    @Test("createReminder returns new reminder ID")
    func createReminderReturnsId() async throws {
        let mockExecutor = MockAppleScriptExecutor()
        await mockExecutor.setMockResult("new-reminder-id-789")
        
        let service = RemindersService(executor: mockExecutor)
        let reminderId = try await service.createReminder(title: "Test Reminder", list: "Reminders", dueDate: nil, notes: nil, priority: 0)
        
        #expect(reminderId == "new-reminder-id-789")
    }
    
    @Test("listLists handles empty output")
    func listListsHandlesEmptyOutput() async throws {
        let mockExecutor = MockAppleScriptExecutor()
        await mockExecutor.setMockResult("")
        
        let service = RemindersService(executor: mockExecutor)
        let lists = try await service.listLists()
        
        #expect(lists.isEmpty)
    }
}
