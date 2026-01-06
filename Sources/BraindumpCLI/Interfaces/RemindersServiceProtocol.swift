import Foundation

public protocol RemindersServiceProtocol: Sendable {
    func listLists() async throws -> [ReminderList]
    func listReminders(list: String?, includeCompleted: Bool) async throws -> [Reminder]
    func getReminder(id: String) async throws -> Reminder?
    func createReminder(title: String, list: String, dueDate: Date?, notes: String?, priority: Int) async throws -> String
    func completeReminder(id: String) async throws
    func uncompleteReminder(id: String) async throws
    func deleteReminder(id: String) async throws
    func searchReminders(query: String) async throws -> [Reminder]
}
