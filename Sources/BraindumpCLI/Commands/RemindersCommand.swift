import ArgumentParser
import Foundation

struct Reminders: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reminders",
        abstract: "Manage Apple Reminders",
        subcommands: [
            ListReminders.self,
            GetReminder.self,
            CreateReminder.self,
            CompleteReminder.self,
            DeleteReminder.self,
            SearchReminders.self,
            Lists.self,
        ],
        defaultSubcommand: ListReminders.self
    )
}

struct ListReminders: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List reminders"
    )
    
    @Option(name: .shortAndLong, help: "Filter by list name")
    var list: String?
    
    @Flag(name: .shortAndLong, help: "Include completed reminders")
    var all: Bool = false
    
    @Flag(name: .shortAndLong, help: "Output as JSON")
    var json: Bool = false
    
    func run() async throws {
        let service = RemindersService()
        let reminders = try await service.listReminders(list: list, includeCompleted: all)
        
        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(reminders)
            print(String(data: data, encoding: .utf8)!)
        } else {
            if reminders.isEmpty {
                print("No reminders found.")
            } else {
                let title = list.map { "Reminders in '\($0)':" } ?? "All Reminders:"
                print("\n\(title)\n")
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .short
                dateFormatter.timeStyle = .short
                
                for (index, reminder) in reminders.enumerated() {
                    let dueStr = reminder.dueDate.map { dateFormatter.string(from: $0) } ?? "No due date"
                    let status = reminder.isCompleted ? "[x]" : "[ ]"
                    let priorityStr = reminder.priority > 0 ? " !" : ""
                    print("\(index + 1). \(status) \(reminder.title)\(priorityStr)")
                    print("      Due: \(dueStr) | List: \(reminder.list)")
                }
            }
        }
    }
}

struct GetReminder: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Get a reminder by ID"
    )
    
    @Argument(help: "Reminder ID")
    var id: String
    
    @Flag(name: .shortAndLong, help: "Output as JSON")
    var json: Bool = false
    
    func run() async throws {
        let service = RemindersService()
        guard let reminder = try await service.getReminder(id: id) else {
            print("Reminder not found.")
            return
        }
        
        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(reminder)
            print(String(data: data, encoding: .utf8)!)
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            
            print("\nTitle: \(reminder.title)")
            print("List: \(reminder.list)")
            print("Status: \(reminder.isCompleted ? "Completed" : "Pending")")
            if let dueDate = reminder.dueDate {
                print("Due: \(dateFormatter.string(from: dueDate))")
            }
            if reminder.priority > 0 {
                print("Priority: \(reminder.priority)")
            }
            if let notes = reminder.notes, !notes.isEmpty {
                print("Notes: \(notes)")
            }
            print("ID: \(reminder.id)")
        }
    }
}

struct CreateReminder: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create",
        abstract: "Create a new reminder"
    )
    
    @Option(name: .shortAndLong, help: "Reminder title")
    var title: String
    
    @Option(name: .shortAndLong, help: "List name")
    var list: String = "Reminders"
    
    @Option(name: .shortAndLong, help: "Due date (YYYY-MM-DD or YYYY-MM-DD HH:MM)")
    var due: String?
    
    @Option(name: .shortAndLong, help: "Notes/description")
    var notes: String?
    
    @Option(name: .shortAndLong, help: "Priority (0=none, 1=high, 5=medium, 9=low)")
    var priority: Int = 0
    
    @Flag(name: .shortAndLong, help: "Output as JSON")
    var json: Bool = false
    
    func run() async throws {
        var dueDate: Date? = nil
        if let dueStr = due {
            let formatter = DateFormatter()
            if dueStr.contains(":") {
                formatter.dateFormat = "yyyy-MM-dd HH:mm"
            } else {
                formatter.dateFormat = "yyyy-MM-dd"
            }
            dueDate = formatter.date(from: dueStr)
        }
        
        let service = RemindersService()
        let reminderId = try await service.createReminder(
            title: title,
            list: list,
            dueDate: dueDate,
            notes: notes,
            priority: priority
        )
        
        if json {
            print("{\"success\": true, \"id\": \"\(reminderId)\"}")
        } else {
            print("Reminder '\(title)' created in '\(list)'.")
        }
    }
}

struct CompleteReminder: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "complete",
        abstract: "Mark a reminder as completed"
    )
    
    @Argument(help: "Reminder ID, index (1, 2...), or partial title")
    var id: String
    
    @Flag(name: .shortAndLong, help: "Uncomplete instead of complete")
    var undo: Bool = false
    
    func run() async throws {
        let service = RemindersService()
        
        // Resolve ID first
        let allReminders = try await service.listReminders(list: nil, includeCompleted: false)
        let resolvedReminder = try IDResolver.resolve(id, from: allReminders)
        
        if undo {
            try await service.uncompleteReminder(id: resolvedReminder.id)
            print("Reminder '\(resolvedReminder.title)' marked as incomplete.")
        } else {
            try await service.completeReminder(id: resolvedReminder.id)
            print("Reminder '\(resolvedReminder.title)' completed.")
        }
    }
}

struct DeleteReminder: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete",
        abstract: "Delete a reminder"
    )
    
    @Argument(help: "Reminder ID, index (1, 2...), or partial title")
    var id: String
    
    @Flag(name: .shortAndLong, help: "Skip confirmation")
    var force: Bool = false
    
    func run() async throws {
        let service = RemindersService()
        
        // Resolve ID first
        let allReminders = try await service.listReminders(list: nil, includeCompleted: false)
        let resolvedReminder = try IDResolver.resolve(id, from: allReminders)
        
        if !force {
            print("Delete reminder '\(resolvedReminder.title)'? [y/N] ", terminator: "")
            guard let response = readLine()?.lowercased(), response == "y" else {
                print("Cancelled.")
                return
            }
        }
        
        try await service.deleteReminder(id: resolvedReminder.id)
        print("Reminder '\(resolvedReminder.title)' deleted.")
    }
}

struct SearchReminders: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search reminders by title"
    )
    
    @Argument(help: "Search query")
    var query: String
    
    @Flag(name: .shortAndLong, help: "Output as JSON")
    var json: Bool = false
    
    func run() async throws {
        let service = RemindersService()
        let reminders = try await service.searchReminders(query: query)
        
        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(reminders)
            print(String(data: data, encoding: .utf8)!)
        } else {
            if reminders.isEmpty {
                print("No reminders found matching '\(query)'.")
            } else {
                print("\nSearch results for '\(query)':\n")
                for (index, reminder) in reminders.enumerated() {
                    let status = reminder.isCompleted ? "[x]" : "[ ]"
                    print("\(index + 1). \(status) \(reminder.title) [\(reminder.list)]")
                }
            }
        }
    }
}

struct Lists: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lists",
        abstract: "List all reminder lists"
    )
    
    @Flag(name: .shortAndLong, help: "Output as JSON")
    var json: Bool = false
    
    func run() async throws {
        let service = RemindersService()
        let lists = try await service.listLists()
        
        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(lists)
            print(String(data: data, encoding: .utf8)!)
        } else {
            print("\nReminder Lists:\n")
            for list in lists {
                print("  \(list.name) (\(list.count) pending)")
            }
        }
    }
}
