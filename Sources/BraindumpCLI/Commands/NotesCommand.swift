import ArgumentParser
import Foundation

struct Notes: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "notes",
        abstract: "Manage Apple Notes",
        subcommands: [
            ListNotes.self,
            GetNote.self,
            CreateNote.self,
            SearchNotes.self,
            DeleteNote.self,
            Folders.self,
        ]
    )
}

struct ListNotes: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all notes"
    )
    
    @Option(name: .shortAndLong, help: "Filter by folder name")
    var folder: String?
    
    @Flag(name: .shortAndLong, help: "Output as JSON")
    var json: Bool = false
    
    func run() async throws {
        let service = NotesService()
        let notes = try await service.listNotes(folder: folder)
        
        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(notes)
            print(String(data: data, encoding: .utf8)!)
        } else {
            if notes.isEmpty {
                print("No notes found.")
            } else {
                let title = folder.map { "Notes in '\($0)':" } ?? "All Notes:"
                print("\n\(title)\n")
                for (index, note) in notes.enumerated() {
                    print("\(index + 1). [\(note.folder)] \(note.title)")
                }
            }
        }
    }
}

struct GetNote: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Get a note by ID"
    )
    
    @Argument(help: "Note ID")
    var id: String
    
    @Flag(name: .shortAndLong, help: "Output as JSON")
    var json: Bool = false
    
    func run() async throws {
        let service = NotesService()
        guard let note = try await service.getNote(id: id) else {
            print("Note not found.")
            return
        }
        
        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(note)
            print(String(data: data, encoding: .utf8)!)
        } else {
            print("\nTitle: \(note.title)")
            print("Folder: \(note.folder)")
            print("ID: \(note.id)")
            if let body = note.body {
                print("\n--- Content ---\n")
                print(body)
            }
        }
    }
}

struct CreateNote: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create",
        abstract: "Create a new note"
    )
    
    @Option(name: .shortAndLong, help: "Note title")
    var title: String
    
    @Option(name: .shortAndLong, help: "Note body/content")
    var body: String = ""
    
    @Option(name: .shortAndLong, help: "Folder name")
    var folder: String = "Notes"
    
    @Flag(name: .shortAndLong, help: "Output as JSON")
    var json: Bool = false
    
    func run() async throws {
        let service = NotesService()
        let noteId = try await service.createNote(title: title, body: body, folder: folder)
        
        if json {
            print("{\"success\": true, \"id\": \"\(noteId)\"}")
        } else {
            print("Note created in '\(folder)' folder.")
        }
    }
}

struct SearchNotes: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search notes by title or content"
    )
    
    @Argument(help: "Search query")
    var query: String
    
    @Flag(name: .shortAndLong, help: "Output as JSON")
    var json: Bool = false
    
    func run() async throws {
        let service = NotesService()
        let notes = try await service.searchNotes(query: query)
        
        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(notes)
            print(String(data: data, encoding: .utf8)!)
        } else {
            if notes.isEmpty {
                print("No notes found matching '\(query)'.")
            } else {
                print("\nSearch results for '\(query)':\n")
                for (index, note) in notes.enumerated() {
                    print("\(index + 1). [\(note.folder)] \(note.title)")
                }
            }
        }
    }
}

struct DeleteNote: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete",
        abstract: "Delete a note by ID"
    )
    
    @Argument(help: "Note ID")
    var id: String
    
    @Flag(name: .shortAndLong, help: "Skip confirmation")
    var force: Bool = false
    
    func run() async throws {
        let service = NotesService()
        
        if !force {
            if let note = try await service.getNote(id: id) {
                print("Delete note '\(note.title)'? [y/N] ", terminator: "")
                guard let response = readLine()?.lowercased(), response == "y" else {
                    print("Cancelled.")
                    return
                }
            }
        }
        
        try await service.deleteNote(id: id)
        print("Note deleted.")
    }
}

struct Folders: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "folders",
        abstract: "List all note folders"
    )
    
    @Flag(name: .shortAndLong, help: "Output as JSON")
    var json: Bool = false
    
    func run() async throws {
        let service = NotesService()
        let folders = try await service.listFolders()
        
        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(folders)
            print(String(data: data, encoding: .utf8)!)
        } else {
            print("\nNote Folders:\n")
            for folder in folders {
                print("  \(folder.name) (\(folder.noteCount) notes)")
            }
        }
    }
}
