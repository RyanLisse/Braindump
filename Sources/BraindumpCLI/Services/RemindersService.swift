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

public actor RemindersService: RemindersServiceProtocol {
    private let executor: any AppleScriptExecutorProtocol
    private let dateFormatter: ISO8601DateFormatter
    
    public init(executor: any AppleScriptExecutorProtocol = AppleScriptRunner()) {
        self.executor = executor
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
        
        let output = try await executor.run(script)
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
            set reminderDataList to {}
            
            -- Construct the reference based on filters
            if "\(includeCompleted)" is "false" then
                if "\(listFilter)" is "" then
                    set targetReminders to reminders whose completed is false
                else
                    -- listFilter contains 'of list "Name"'
                    -- We need to splice it: reminders of list "Name" whose completed is false
                    -- But AppleScript syntax is: reminders of list "Name" whose completed is false
                    -- My listFilter variable includes "of list ...".
                    -- So I can just do: reminders \(listFilter) whose completed is false
                    set targetReminders to reminders \(listFilter) whose completed is false
                end if
            else
                set targetReminders to reminders \(listFilter)
            end if
            
            if (count of targetReminders) > 0 then
                set idList to id of targetReminders
                set nameList to name of targetReminders
                set listList to name of container of targetReminders
                set completedList to completed of targetReminders
                set priorityList to priority of targetReminders
                -- due date list might contain 'missing value', which is tricky in lists but handleable
                set dateList to due date of targetReminders
                
                set remCount to count of idList
                repeat with i from 1 to remCount
                    set remID to item i of idList
                    set remName to item i of nameList
                    set remList to item i of listList
                    set isComp to item i of completedList
                    set remPriority to item i of priorityList
                    set rawDueDate to item i of dateList
                    
                    set dueDateStr to "none"
                    try
                        if rawDueDate is not missing value then
                            set dueDate to rawDueDate
                            set dueDateStr to (year of dueDate as string) & "-" & (my padZero(month of dueDate as integer)) & "-" & (my padZero(day of dueDate)) & "T" & (my padZero(hours of dueDate)) & ":" & (my padZero(minutes of dueDate)) & ":00"
                        end if
                    end try
                    
                    set end of reminderDataList to remID & "|" & remList & "|" & remName & "|" & dueDateStr & "|" & isComp & "|" & remPriority
                end repeat
            end if
        end tell
        
        set AppleScript's text item delimiters to "\n"
        return reminderDataList as text
        
        on padZero(n)
            if n < 10 then
                return "0" & (n as string)
            else
                return n as string
            end if
        end padZero
        """
        
        let output = try await executor.run(script)
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
        
        let output = try await executor.run(script)
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
        
        return try await executor.run(script)
    }
    
    public func completeReminder(id: String) async throws {
        let script = """
        tell application "Reminders"
            set r to first reminder whose id is "\(id)"
            set completed of r to true
        end tell
        """
        
        _ = try await executor.run(script)
    }
    
    public func uncompleteReminder(id: String) async throws {
        let script = """
        tell application "Reminders"
            set r to first reminder whose id is "\(id)"
            set completed of r to false
        end tell
        """
        
        _ = try await executor.run(script)
    }
    
    public func deleteReminder(id: String) async throws {
        let script = """
        tell application "Reminders"
            set r to first reminder whose id is "\(id)"
            delete r
        end tell
        """
        
        _ = try await executor.run(script)
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
        
        _ = try await executor.run(script)
    }
    
    public func searchReminders(query: String) async throws -> [Reminder] {
        let escapedQuery = query.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Reminders"
            set reminderDataList to {}
            set searchQuery to "\(escapedQuery)"
            set matchingReminders to reminders whose name contains searchQuery
            
            if (count of matchingReminders) > 0 then
                set idList to id of matchingReminders
                set nameList to name of matchingReminders
                set listList to name of container of matchingReminders
                set completedList to completed of matchingReminders
                set priorityList to priority of matchingReminders
                 set dateList to due date of matchingReminders
                
                set remCount to count of idList
                repeat with i from 1 to remCount
                    set remID to item i of idList
                    set remName to item i of nameList
                    set remList to item i of listList
                    set isComp to item i of completedList
                    set remPriority to item i of priorityList
                     set rawDueDate to item i of dateList
                    
                    set dueDateStr to "none"
                     try
                        if rawDueDate is not missing value then
                            set dueDate to rawDueDate
                            set dueDateStr to (year of dueDate as string) & "-" & (my padZero(month of dueDate as integer)) & "-" & (my padZero(day of dueDate)) & "T" & (my padZero(hours of dueDate)) & ":" & (my padZero(minutes of dueDate)) & ":00"
                        end if
                    end try
                    
                    set end of reminderDataList to remID & "|" & remList & "|" & remName & "|" & dueDateStr & "|" & isComp & "|" & remPriority
                end repeat
            end if
        end tell
        
        set AppleScript's text item delimiters to "\n"
        return reminderDataList as text
        
        on padZero(n)
            if n < 10 then
                return "0" & (n as string)
            else
                return n as string
            end if
        end padZero
        """
        
        let output = try await executor.run(script)
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
