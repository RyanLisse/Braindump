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
        tell application "Notes"
            set output to ""
            repeat with f in folders \(folderFilter)
                set folderName to name of f
                if folderName is not in deletedNames then
                    repeat with n in notes of f
                        set noteID to id of n
                        set noteName to name of n
                        set modDate to modification date of n
                        set modDateStr to (year of modDate as string) & "-" & (my padZero(month of modDate as integer)) & "-" & (my padZero(day of modDate)) & "T" & (my padZero(hours of modDate)) & ":" & (my padZero(minutes of modDate)) & ":00"
                        set output to output & noteID & "|" & folderName & "|" & noteName & "|" & modDateStr & "\\n"
                    end repeat
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
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        
        let output = try await executor.run(script)
        return output.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "|", maxSplits: 3)
            guard parts.count >= 3 else { return nil }
            
            var modDate: Date? = nil
            if parts.count >= 4 {
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
            set output to ""
            set matchingNotes to notes whose name contains "\(query)" or plaintext contains "\(query)"
            repeat with n in matchingNotes
                set noteID to id of n
                set noteName to name of n
                set noteFolder to name of container of n
                set output to output & noteID & "|" & noteFolder & "|" & noteName & "\\n"
            end repeat
            return output
        end tell
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
