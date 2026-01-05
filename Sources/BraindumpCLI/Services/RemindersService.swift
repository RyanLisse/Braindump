import Foundation

public struct Reminder: Codable, Sendable {
    public let id: String
    public let title: String
    public let list: String
    public let dueDate: Date?
    public let isCompleted: Bool
    public let notes: String?
    public let priority: Int
    
    public init(id: String, title: String, list: String, dueDate: Date? = nil, isCompleted: Bool = false, notes: String? = nil, priority: Int = 0) {
        self.id = id
        self.title = title
        self.list = list
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.notes = notes
        self.priority = priority
    }
}

public struct ReminderList: Codable, Sendable {
    public let name: String
    public let count: Int
    
    public init(name: String, count: Int) {
        self.name = name
        self.count = count
    }
}

public actor RemindersService {
    private let runner = AppleScriptRunner()
    private let dateFormatter: ISO8601DateFormatter
    
    public init() {
        dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
    }
    
    public func listLists() async throws -> [ReminderList] {
        let script = """
        tell application "Reminders"
            set output to ""
            repeat with l in lists
                set listName to name of l
                set remCount to 0
                repeat with r in reminders in l
                    if completed of r is false then
                        set remCount to remCount + 1
                    end if
                end repeat
                set output to output & listName & "|" & remCount & "\\n"
            end repeat
            return output
        end tell
        """
        
        let output = try await runner.run(script)
        return output.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "|")
            guard parts.count >= 2,
                  let count = Int(parts[1]) else { return nil }
            return ReminderList(name: String(parts[0]), count: count)
        }
    }
    
    public func listReminders(list: String? = nil, includeCompleted: Bool = false) async throws -> [Reminder] {
        let listFilter = list.map { "of list \"\($0)\"" } ?? ""
        let completedCheck = includeCompleted ? "true" : "(completed of r is false)"
        
        let script = """
        tell application "Reminders"
            set output to ""
            set rems to reminders \(listFilter)
            repeat with r in rems
                if \(completedCheck) then
                    set remID to id of r
                    set remName to name of r
                    set remList to name of container of r
                    set isComp to completed of r
                    set remPriority to priority of r
                    set dueDateStr to "none"
                    try
                        set dueDate to due date of r
                        if dueDate is not missing value then
                            set dueDateStr to (year of dueDate as string) & "-" & (my padZero(month of dueDate as integer)) & "-" & (my padZero(day of dueDate)) & "T" & (my padZero(hours of dueDate)) & ":" & (my padZero(minutes of dueDate)) & ":00"
                        end if
                    end try
                    set output to output & remID & "|" & remList & "|" & remName & "|" & dueDateStr & "|" & isComp & "|" & remPriority & "\\n"
                end if
            end repeat
            return output
        end tell
        
        on padZero(n)
            if n < 10 then
                return "0" & (n as string)
            else
                return n as string
            end if
        end padZero
        """
        
        let output = try await runner.run(script)
        return output.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "|", maxSplits: 5)
            guard parts.count >= 6 else { return nil }
            
            let dueDateStr = String(parts[3])
            var dueDate: Date? = nil
            if dueDateStr != "none" {
                dueDate = dateFormatter.date(from: dueDateStr + "Z")
            }
            
            return Reminder(
                id: String(parts[0]),
                title: String(parts[2]),
                list: String(parts[1]),
                dueDate: dueDate,
                isCompleted: String(parts[4]) == "true",
                priority: Int(String(parts[5])) ?? 0
            )
        }
    }
    
    public func getReminder(id: String) async throws -> Reminder? {
        let script = """
        tell application "Reminders"
            set r to first reminder whose id is "\(id)"
            set remID to id of r
            set remName to name of r
            set remList to name of container of r
            set isComp to completed of r
            set remPriority to priority of r
            set remNotes to ""
            try
                set remNotes to body of r
            end try
            set dueDateStr to "none"
            try
                set dueDate to due date of r
                if dueDate is not missing value then
                    set dueDateStr to (year of dueDate as string) & "-" & (my padZero(month of dueDate as integer)) & "-" & (my padZero(day of dueDate)) & "T" & (my padZero(hours of dueDate)) & ":" & (my padZero(minutes of dueDate)) & ":00"
                end if
            end try
            return remID & "|" & remList & "|" & remName & "|" & dueDateStr & "|" & isComp & "|" & remPriority & "|" & remNotes
        end tell
        
        on padZero(n)
            if n < 10 then
                return "0" & (n as string)
            else
                return n as string
            end if
        end padZero
        """
        
        let output = try await runner.run(script)
        let parts = output.split(separator: "|", maxSplits: 6)
        guard parts.count >= 6 else { return nil }
        
        let dueDateStr = String(parts[3])
        var dueDate: Date? = nil
        if dueDateStr != "none" {
            dueDate = dateFormatter.date(from: dueDateStr + "Z")
        }
        
        return Reminder(
            id: String(parts[0]),
            title: String(parts[2]),
            list: String(parts[1]),
            dueDate: dueDate,
            isCompleted: String(parts[4]) == "true",
            notes: parts.count > 6 ? String(parts[6]) : nil,
            priority: Int(String(parts[5])) ?? 0
        )
    }
    
    public func createReminder(title: String, list: String, dueDate: Date? = nil, notes: String? = nil, priority: Int = 0) async throws -> String {
        let escapedTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
        
        var dueDateScript = ""
        if let date = dueDate {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            dueDateScript = """
            set dueDate to current date
            set year of dueDate to \(components.year ?? 2026)
            set month of dueDate to \(components.month ?? 1)
            set day of dueDate to \(components.day ?? 1)
            set hours of dueDate to \(components.hour ?? 0)
            set minutes of dueDate to \(components.minute ?? 0)
            set due date of newRem to dueDate
            """
        }
        
        let notesScript = notes.map { ", body:\"\($0.replacingOccurrences(of: "\"", with: "\\\""))\"" } ?? ""
        
        let script = """
        tell application "Reminders"
            tell list "\(list)"
                set newRem to make new reminder with properties {name:"\(escapedTitle)", priority:\(priority)\(notesScript)}
                \(dueDateScript)
                return id of newRem
            end tell
        end tell
        """
        
        return try await runner.run(script)
    }
    
    public func completeReminder(id: String) async throws {
        let script = """
        tell application "Reminders"
            set r to first reminder whose id is "\(id)"
            set completed of r to true
        end tell
        """
        
        _ = try await runner.run(script)
    }
    
    public func uncompleteReminder(id: String) async throws {
        let script = """
        tell application "Reminders"
            set r to first reminder whose id is "\(id)"
            set completed of r to false
        end tell
        """
        
        _ = try await runner.run(script)
    }
    
    public func deleteReminder(id: String) async throws {
        let script = """
        tell application "Reminders"
            set r to first reminder whose id is "\(id)"
            delete r
        end tell
        """
        
        _ = try await runner.run(script)
    }
    
    public func updateReminder(id: String, title: String? = nil, dueDate: Date? = nil, notes: String? = nil, priority: Int? = nil) async throws {
        var updates: [String] = []
        
        if let title = title {
            updates.append("set name of r to \"\(title.replacingOccurrences(of: "\"", with: "\\\""))\"")
        }
        
        if let notes = notes {
            updates.append("set body of r to \"\(notes.replacingOccurrences(of: "\"", with: "\\\""))\"")
        }
        
        if let priority = priority {
            updates.append("set priority of r to \(priority)")
        }
        
        var dueDateScript = ""
        if let date = dueDate {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            dueDateScript = """
            set dueDate to current date
            set year of dueDate to \(components.year ?? 2026)
            set month of dueDate to \(components.month ?? 1)
            set day of dueDate to \(components.day ?? 1)
            set hours of dueDate to \(components.hour ?? 0)
            set minutes of dueDate to \(components.minute ?? 0)
            set due date of r to dueDate
            """
        }
        
        let script = """
        tell application "Reminders"
            set r to first reminder whose id is "\(id)"
            \(updates.joined(separator: "\n            "))
            \(dueDateScript)
        end tell
        """
        
        _ = try await runner.run(script)
    }
    
    public func searchReminders(query: String) async throws -> [Reminder] {
        let escapedQuery = query.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Reminders"
            set output to ""
            set searchQuery to "\(escapedQuery)"
            repeat with r in reminders
                if name of r contains searchQuery then
                    set remID to id of r
                    set remName to name of r
                    set remList to name of container of r
                    set isComp to completed of r
                    set remPriority to priority of r
                    set dueDateStr to "none"
                    try
                        set dueDate to due date of r
                        if dueDate is not missing value then
                            set dueDateStr to (year of dueDate as string) & "-" & (my padZero(month of dueDate as integer)) & "-" & (my padZero(day of dueDate)) & "T" & (my padZero(hours of dueDate)) & ":" & (my padZero(minutes of dueDate)) & ":00"
                        end if
                    end try
                    set output to output & remID & "|" & remList & "|" & remName & "|" & dueDateStr & "|" & isComp & "|" & remPriority & "\\n"
                end if
            end repeat
            return output
        end tell
        
        on padZero(n)
            if n < 10 then
                return "0" & (n as string)
            else
                return n as string
            end if
        end padZero
        """
        
        let output = try await runner.run(script)
        return output.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "|", maxSplits: 5)
            guard parts.count >= 6 else { return nil }
            
            let dueDateStr = String(parts[3])
            var dueDate: Date? = nil
            if dueDateStr != "none" {
                dueDate = dateFormatter.date(from: dueDateStr + "Z")
            }
            
            return Reminder(
                id: String(parts[0]),
                title: String(parts[2]),
                list: String(parts[1]),
                dueDate: dueDate,
                isCompleted: String(parts[4]) == "true",
                priority: Int(String(parts[5])) ?? 0
            )
        }
    }
}
