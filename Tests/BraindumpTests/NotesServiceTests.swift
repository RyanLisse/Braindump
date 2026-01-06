import Testing
import Foundation
@testable import BraindumpCLI

@Suite("NotesService Tests")
struct NotesServiceTests {
    
    @Test("listFolders parses pipe-delimited output correctly")
    func listFoldersParsesOutput() async throws {
        let mockExecutor = MockAppleScriptExecutor()
        await mockExecutor.setMockResult("Notes|5\nWork|12\nPersonal|3\n")
        
        let service = NotesService(executor: mockExecutor)
        let folders = try await service.listFolders()
        
        #expect(folders.count == 3)
        #expect(folders[0].name == "Notes")
        #expect(folders[0].noteCount == 5)
        #expect(folders[1].name == "Work")
        #expect(folders[1].noteCount == 12)
    }
    
    @Test("listNotes parses pipe-delimited output correctly")
    func listNotesParsesOutput() async throws {
        let mockExecutor = MockAppleScriptExecutor()
        await mockExecutor.setMockResult("id123|Notes|My First Note\nid456|Work|Meeting Notes\n")
        
        let service = NotesService(executor: mockExecutor)
        let notes = try await service.listNotes(folder: nil)
        
        #expect(notes.count == 2)
        #expect(notes[0].id == "id123")
        #expect(notes[0].folder == "Notes")
        #expect(notes[0].title == "My First Note")
        #expect(notes[1].id == "id456")
        #expect(notes[1].folder == "Work")
    }
    
    @Test("getNote parses full note with body")
    func getNoteParsesFullOutput() async throws {
        let mockExecutor = MockAppleScriptExecutor()
        await mockExecutor.setMockResult("id123|Notes|My Note|<html><body>Hello World</body></html>")
        
        let service = NotesService(executor: mockExecutor)
        let note = try await service.getNote(id: "id123")
        
        #expect(note != nil)
        #expect(note?.id == "id123")
        #expect(note?.folder == "Notes")
        #expect(note?.title == "My Note")
        #expect(note?.body == "<html><body>Hello World</body></html>")
    }
    
    @Test("searchNotes returns matching notes")
    func searchNotesReturnsMatches() async throws {
        let mockExecutor = MockAppleScriptExecutor()
        await mockExecutor.setMockResult("id789|Personal|Shopping List\n")
        
        let service = NotesService(executor: mockExecutor)
        let notes = try await service.searchNotes(query: "Shopping")
        
        #expect(notes.count == 1)
        #expect(notes[0].title == "Shopping List")
    }
    
    @Test("listFolders handles empty output")
    func listFoldersHandlesEmptyOutput() async throws {
        let mockExecutor = MockAppleScriptExecutor()
        await mockExecutor.setMockResult("")
        
        let service = NotesService(executor: mockExecutor)
        let folders = try await service.listFolders()
        
        #expect(folders.isEmpty)
    }
    
    @Test("createNote returns new note ID")
    func createNoteReturnsId() async throws {
        let mockExecutor = MockAppleScriptExecutor()
        await mockExecutor.setMockResult("new-note-id-123")
        
        let service = NotesService(executor: mockExecutor)
        let noteId = try await service.createNote(title: "Test Note", body: "Test Body", folder: "Notes")
        
        #expect(noteId == "new-note-id-123")
    }
}
