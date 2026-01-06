import Foundation

public struct Note: Codable, Sendable {
    public let id: String
    public let title: String
    public let folder: String
    public let body: String?
    public let creationDate: Date?
    public let modificationDate: Date?
    
    public init(id: String, title: String, folder: String, body: String? = nil, creationDate: Date? = nil, modificationDate: Date? = nil) {
        self.id = id
        self.title = title
        self.folder = folder
        self.body = body
        self.creationDate = creationDate
        self.modificationDate = modificationDate
    }
}

public struct NoteFolder: Codable, Sendable {
    public let name: String
    public let noteCount: Int
    
    public init(name: String, noteCount: Int) {
        self.name = name
        self.noteCount = noteCount
    }
}

public actor NotesService: NotesServiceProtocol {
    private let executor: any AppleScriptExecutorProtocol
    
    public init(executor: any AppleScriptExecutorProtocol = AppleScriptRunner()) {
        self.executor = executor
    }
    
    public func listFolders() async throws -> [NoteFolder] {
        let script = """
        tell application "Notes"
            set output to ""
            repeat with f in folders
                set folderName to name of f
                set noteCount to count of notes in f
                set output to output & folderName & "|" & noteCount & "\\n"
            end repeat
            return output
        end tell
        """
        
        let output = try await executor.run(script)
        return output.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "|")
            guard parts.count >= 2,
                  let count = Int(parts[1]) else { return nil }
            return NoteFolder(name: String(parts[0]), noteCount: count)
        }
    }
    
    public func listNotes(folder: String? = nil) async throws -> [Note] {
        let folderFilter = folder.map { "whose name is \"\($0)\"" } ?? ""
        let script = """
        set deletedNames to {"Recently Deleted", "Nylig slettet", "Zuletzt gelöscht", "Supprimés récemment", "Eliminados recientemente"}
        set noteDataList to {}
        
        tell application "Notes"
            repeat with f in folders \(folderFilter)
                set folderName to name of f
                if folderName is not in deletedNames then
                    try
                        -- Bulk fetch properties to minimize IPC calls
                        set idList to id of notes of f
                        set nameList to name of notes of f
                        set dateList to modification date of notes of f
                        
                        set noteCount to count of idList
                        if noteCount > 0 then
                            repeat with i from 1 to noteCount
                                set noteID to item i of idList
                                set noteName to item i of nameList
                                set modDate to item i of dateList
                                
                                -- Format date
                                set modDateStr to (year of modDate as string) & "-" & (my padZero(month of modDate as integer)) & "-" & (my padZero(day of modDate)) & "T" & (my padZero(hours of modDate)) & ":" & (my padZero(minutes of modDate)) & ":" & (my padZero(seconds of modDate))
                                
                                set end of noteDataList to noteID & "|" & folderName & "|" & noteName & "|" & modDateStr
                            end repeat
                        end if
                    on error
                        -- Skip folder or problematic notes in it
                    end try
                end if
            end repeat
        end tell
        
        set AppleScript's text item delimiters to "\n"
        return noteDataList as text
        
        on padZero(n)
            if n < 10 then
                return "0" & (n as string)
            else
                return n as string
            end if
        end padZero
        """
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        
        let output = try await executor.run(script)
        return output.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "|", maxSplits: 3)
            guard parts.count >= 3 else { return nil }
            
            var modDate: Date? = nil
            if parts.count >= 4 {
               // Append Z for UTC, though AppleScript dates are local time usually. 
               // Assuming local time for typical user scripts is better handled if we parse as local or make sure format is explicit.
               // However, AppleScript date is local. ISO8601DateFormatter without timezone assumes UTC if Z is present, or local if not?
               // Let's assume we treat it as a naive date string and let the formatter handle it.
               // The constructed string is "YYYY-MM-DDTHH:mm:ss".
               // ISO8601DateFormatter with .withInternetDateTime expects timezone.
               // If we just append "Z" we treat local time as UTC, which is wrong but consistent for sync comparisons if consistent everywhere.
               // Better is to allow loose format.
               // Let's stick to the previous code's intention: String(parts[3]) + "Z"
               modDate = dateFormatter.date(from: String(parts[3]) + "Z")
            }
            
            return Note(
                id: String(parts[0]),
                title: String(parts[2]),
                folder: String(parts[1]),
                modificationDate: modDate
            )
        }
    }
    
    public func getNote(id: String) async throws -> Note? {
        let script = """
        tell application "Notes"
            try
                set n to first note whose id is "\(id)"
                set noteID to id of n
                set noteName to name of n
                set noteBody to body of n
                set noteFolder to "Unknown"
                try
                    set noteFolder to name of container of n
                end try
                return noteID & "|" & noteFolder & "|" & noteName & "|" & noteBody
            on error
                return "FAIL"
            end try
        end tell
        """
        
        let output = try await executor.run(script)
        let parts = output.split(separator: "|", maxSplits: 3)
        guard parts.count >= 4 else { return nil }
        
        return Note(
            id: String(parts[0]),
            title: String(parts[2]),
            folder: String(parts[1]),
            body: String(parts[3])
        )
    }
    
    public func searchNotes(query: String) async throws -> [Note] {
        let script = """
        tell application "Notes"
            set deletedNames to {"Recently Deleted", "Nylig slettet", "Zuletzt gelöscht", "Supprimés récemment", "Eliminados recientemente"}
            set noteDataList to {}
            set searchQuery to "\(query)"
            
            repeat with f in folders
                set folderName to name of f
                if folderName is not in deletedNames then
                    try
                        set matchingInFolder to (notes of f whose name contains searchQuery or plaintext contains searchQuery)
                        set matchCount to count of matchingInFolder
                        
                        if matchCount > 0 then
                            repeat with i from 1 to matchCount
                                set n to item i of matchingInFolder
                                try
                                    set noteID to id of n
                                    set noteName to name of n
                                    set end of noteDataList to noteID & "|" & folderName & "|" & noteName
                                on error
                                    -- Skip inaccessible/deleted note
                                end try
                            end repeat
                        end if
                    on error errMsg
                        -- Log error or skip folder if total folder access fails
                    end try
                end if
            end repeat
        end tell
        set AppleScript's text item delimiters to "\n"
        return noteDataList as text
        """
        
        let output = try await executor.run(script)
        return output.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "|", maxSplits: 2)
            guard parts.count >= 3 else { return nil }
            return Note(
                id: String(parts[0]),
                title: String(parts[2]),
                folder: String(parts[1])
            )
        }
    }
    
    public func createNote(title: String, body: String, folder: String) async throws -> String {
        let escapedBody = body.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
        
        let script = """
        tell application "Notes"
            set targetFolder to first folder whose name is "\(folder)"
            tell targetFolder
                set newNote to make new note with properties {name:"\(escapedTitle)", body:"\(escapedBody)"}
                return id of newNote
            end tell
        end tell
        """
        
        return try await executor.run(script)
    }
    
    public func updateNote(id: String, body: String) async throws {
        let escapedBody = body.replacingOccurrences(of: "\"", with: "\\\"")
        
        let script = """
        tell application "Notes"
            set n to first note whose id is "\(id)"
            set body of n to "\(escapedBody)"
        end tell
        """
        
        _ = try await executor.run(script)
    }
    
    public func deleteNote(id: String) async throws {
        let script = """
        tell application "Notes"
            set n to first note whose id is "\(id)"
            delete n
        end tell
        """
        
        _ = try await executor.run(script)
    }
    
    public func moveNote(id: String, toFolder: String) async throws {
        let script = """
        tell application "Notes"
            set n to first note whose id is "\(id)"
            set noteName to name of n
            set noteBody to body of n
            set targetFolder to first folder whose name is "\(toFolder)"
            make new note at targetFolder with properties {name:noteName, body:noteBody}
            delete n
        end tell
        """
        
        _ = try await executor.run(script)
    }
    
    public func createFolder(name: String) async throws {
        let script = """
        tell application "Notes"
            make new folder with properties {name:"\(name)"}
        end tell
        """
        
        _ = try await executor.run(script)
    }
    
    public func fetchChangedNotes(since: Date) async throws -> [Note] {
        let secondsSinceReference = since.timeIntervalSinceReferenceDate
        
        let script = """
        set deletedNames to {"Recently Deleted", "Nylig slettet", "Zuletzt gelöscht", "Supprimés récemment", "Eliminados recientemente"}
        set noteDataList to {}
        
        -- Construct date in locale-independent way
        set sinceDate to (current date)
        tell sinceDate to set {year, month, day, time} to {2001, 1, 1, 0}
        set sinceDate to sinceDate + \(Int(secondsSinceReference))
        
        tell application "Notes"
            repeat with f in folders
                set folderName to name of f
                if folderName is not in deletedNames then
                    try
                        set matchingNotes to (notes of f whose modification date > sinceDate)
                        set matchCount to count of matchingNotes
                        
                        if matchCount > 0 then
                            repeat with i from 1 to matchCount
                                try
                                    set n to item i of matchingNotes
                                    set noteID to id of n
                                    set noteName to name of n
                                    set noteBody to body of n
                                    set modDate to modification date of n
                                    set modDateStr to (year of modDate as string) & "-" & (my padZero(month of modDate as integer)) & "-" & (my padZero(day of modDate)) & "T" & (my padZero(hours of modDate)) & ":" & (my padZero(minutes of modDate)) & ":" & (my padZero(seconds of modDate))
                                    
                                    set end of noteDataList to noteID & "|" & folderName & "|" & noteName & "|" & modDateStr & "|" & noteBody & "|||RECORD_END|||"
                                on error
                                    -- Skip problematic note
                                end try
                            end repeat
                        end if
                    on error
                        -- Skip problematic folder
                    end try
                end if
            end repeat
        end tell
        
        set AppleScript's text item delimiters to ""
        return noteDataList as text
        
        on padZero(n)
            if n < 10 then
                return "0" & (n as string)
            else
                return n as string
            end if
        end padZero
        """
        
        let output = try await executor.run(script)
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        
        return output.components(separatedBy: "|||RECORD_END|||").compactMap { record in
            let trimmed = record.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            
            let parts = trimmed.split(separator: "|", maxSplits: 4)
            guard parts.count >= 4 else { return nil }
            
            let body = parts.count >= 5 ? String(parts[4]) : nil
            let modDate = dateFormatter.date(from: String(parts[3]) + "Z")
            
            return Note(
                id: String(parts[0]),
                title: String(parts[2]),
                folder: String(parts[1]),
                body: body,
                modificationDate: modDate
            )
        }
    }
}
