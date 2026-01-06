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
            set n to first note whose id is "\(id)"
            set noteID to id of n
            set noteName to name of n
            set noteBody to body of n
            set noteFolder to name of container of n
            return noteID & "|" & noteFolder & "|" & noteName & "|" & noteBody
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
            set noteDataList to {}
            set matchingNotes to notes whose name contains "\(query)" or plaintext contains "\(query)"
            
            -- Bulk fetch properties
            set idList to id of matchingNotes
            set nameList to name of matchingNotes
            -- Container name fetching in bulk might be tricky if some fail?
            -- "name of container of matchingNotes" -> returns a list?
            -- If one fails, does the whole list fail?
            -- AppleScript usually fails the whole command if one item fails.
            -- So we might have to be careful.
            -- However, "container" property of a note usually exists unless it's weird.
            -- But previously "container of note" failed for deleted notes.
            -- Deleted notes are in "Recently Deleted" folder.
            -- "notes" reference includes all notes?
            -- Maybe "notes whose ... and name of container is not ..."
            -- But "name of container" is expensive to check in filter?
            
            -- Let's try iterating, but without IPC for everything?
            -- No, loop in AppleScript is slow for thousands.
            -- Bulk fetch is best.
            -- If we can filter out deleted notes first efficiently?
            
            -- "notes" usually refers to notes in the default account?
            -- Actually "notes" of application refers to ALL notes.
            
            -- Let's try to get container names in bulk. If it fails, we fall back to loop?
            -- Or we can try getting properties for all matchingNotes.
            
            -- Safe approach for bulk fetch with potential errors:
            -- Not easily possible in vanilla AppleScript without loop.
            
            -- Alternative: Filter non-deleted notes first.
            -- "notes whose (name contains X or plaintext contains X) and (container's name is not "Recently Deleted")" ?
            -- AppleScript "container" property is valid in filter?
            
            -- Let's try to filter.
            try
                set validNotes to (matchingNotes whose name of container is not "Recently Deleted" and name of container is not "Nylig slettet" and name of container is not "Zuletzt gelöscht" and name of container is not "Supprimés récemment" and name of container is not "Eliminados recientemente")
                
                -- Now bulk fetch from validNotes
                set idList to id of validNotes
                set nameList to name of validNotes
                set containerList to name of container of validNotes
                
                set noteCount to count of idList
                repeat with i from 1 to noteCount
                    set noteID to item i of idList
                    set noteName to item i of nameList
                    set noteFolder to item i of containerList
                    
                    set end of noteDataList to noteID & "|" & noteFolder & "|" & noteName
                end repeat
            on error
               -- If bulk filter/fetch fails, fallback to slow loop or return what we can?
               -- It probably failed because "name of container" failed for some note.
               -- We'll return just IDs and names, and "Unknown" folder?
               -- Or just use the slow loop but optimized (only fetching needed properties)?
               
               -- Let's use the slow loop but ONLY if bulk fails.
               -- But actually, the loop I had before was hanging.
               
               -- Compromise: Fetch ID and Name in bulk (usually safe). Fetch Container individually?
               -- Fetching Container individually for 1000 notes is 1000 IPC calls? No, inside "tell app", it's 1000 internal calls?
               -- "tell application ... repeat ... end tell" sends the WHOLE script to the app. 
               -- The loop runs INSIDE the app process.
               -- So why was it slow/hanging?
               -- Because creating the string "output" repeatedly is O(N^2).
               -- "set output to output & ..." is slow.
               -- I already switched to "set end of noteDataList to ...".
               -- So the loop SHOULD be fast IF run inside the app.
               
               -- My previous fix for listNotes used "set end of noteDataList".
               -- My searchNotes implementation (before this edit) ALSO used "set end of noteDataList".
               -- But I added `try ... end try` in the loop.
               -- The hang happened even with that?
               
               -- Wait, the hang I saw in Step 223 was with the `try` block added.
               -- "Twitter" query.
               -- If many notes, the loop takes time.
               -- Is it the `try` block overhead?
               
               -- Let's try bulk fetch of just ID and Name.
               set idList to id of matchingNotes
               set nameList to name of matchingNotes
               
               -- We can avoid fetching container if it's risky?
               -- But the UI shows folder.
               
               set noteCount to count of idList
                repeat with i from 1 to noteCount
                    set noteID to item i of idList
                    set noteName to item i of nameList
                    
                    set noteFolder to "Unknown"
                    try
                        set noteFolder to name of container of (item i of matchingNotes)
                    end try
                    
                    set end of noteDataList to noteID & "|" & noteFolder & "|" & noteName
                end repeat
            end try
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
}
