import Foundation

actor NotesSyncService {
    private let notesService: NotesService
    private let databaseService: DatabaseService
    private let htmlConverter: HTMLConverterService
    private let embeddingService: EmbeddingService
    
    init(notesService: NotesService, databaseService: DatabaseService, htmlConverter: HTMLConverterService, embeddingService: EmbeddingService) {
        self.notesService = notesService
        self.databaseService = databaseService
        self.htmlConverter = htmlConverter
        self.embeddingService = embeddingService
    }
    
    func sync() async throws -> (processed: Int, skipped: Int, errors: Int) {
        // Ensure DB is ready
        try await databaseService.setup()
        
        let notes = try await notesService.listNotes()
        let lastSyncStr = try await databaseService.getSyncState(key: "last_sync")
        let lastSyncDate = ISO8601DateFormatter().date(from: lastSyncStr ?? "") ?? Date.distantPast
        
        var processed = 0
        var skipped = 0
        var errors = 0
        
        for note in notes {
            // Check if we need to process this note
            if let modDate = note.modificationDate, modDate <= lastSyncDate {
                skipped += 1
                continue
            }
            
            // Note: DB check is better than memory list check if list is huge, 
            // but for now we trust the modification date from the list.
            // However, we need to fetch the body, which is expensive.
            
            do {
                guard let fullNote = try await notesService.getNote(id: note.id),
                      let body = fullNote.body else {
                    continue
                }
                
                // Convert HTML to Markdown
                let markdown = try await htmlConverter.convert(body)
                
                // Create Vector (embedding)
                // We embed the combined title and content for better retrieval
                let contentToEmbed = "\(note.title)\n\n\(markdown)"
                let vector = await embeddingService.generateEmbedding(for: contentToEmbed)
                
                let record = NoteRecord(
                    id: note.id,
                    title: note.title,
                    folder: note.folder,
                    markdownContent: markdown,
                    rawHtml: body,
                    modificationDate: note.modificationDate,
                    vector: vector
                )
                
                try await databaseService.saveNote(record)
                processed += 1
                
                // Print progress to stderr so it doesn't pollute stdout (if used in pipes)
                FileHandle.standardError.write("Synced: \(note.title)\n".data(using: .utf8)!)
                
            } catch {
                errors += 1
                FileHandle.standardError.write("Failed to sync \(note.title): \(error)\n".data(using: .utf8)!)
            }
        }
        
        // Update last sync date
        let now = ISO8601DateFormatter().string(from: Date())
        try await databaseService.saveSyncState(key: "last_sync", value: now)
        
        return (processed, skipped, errors)
    }
}
