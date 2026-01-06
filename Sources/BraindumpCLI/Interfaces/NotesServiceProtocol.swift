import Foundation

public protocol NotesServiceProtocol: Sendable {
    func listFolders() async throws -> [NoteFolder]
    func listNotes(folder: String?) async throws -> [Note]
    func getNote(id: String) async throws -> Note?
    func searchNotes(query: String) async throws -> [Note]
    func createNote(title: String, body: String, folder: String) async throws -> String
    func updateNote(id: String, body: String) async throws
    func deleteNote(id: String) async throws
    func moveNote(id: String, toFolder: String) async throws
    func createFolder(name: String) async throws
}
