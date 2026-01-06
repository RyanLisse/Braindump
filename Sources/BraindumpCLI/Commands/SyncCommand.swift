import ArgumentParser
import Foundation

struct Sync: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sync",
        abstract: "Sync Apple Notes to local search index"
    )
    
    @Flag(name: .shortAndLong, help: "Output as JSON")
    var json: Bool = false
    
    func run() async throws {
        let notesService = NotesService()
        let databaseService = DatabaseService()
        let htmlConverter = HTMLConverterService()
        let embeddingService = EmbeddingService()
        
        let syncService = NotesSyncService(
            notesService: notesService,
            databaseService: databaseService,
            htmlConverter: htmlConverter,
            embeddingService: embeddingService
        )
        
        if !json {
            print("Syncing notes to local index...")
        }
        
        let result = try await syncService.sync()
        
        if json {
            let output: [String: Any] = [
                "processed": result.processed,
                "skipped": result.skipped,
                "errors": result.errors
            ]
            let data = try JSONSerialization.data(withJSONObject: output, options: .prettyPrinted)
            print(String(data: data, encoding: .utf8)!)
        } else {
            print("\nSync complete:")
            print("  Processed: \(result.processed)")
            print("  Skipped (unchanged): \(result.skipped)")
            print("  Errors: \(result.errors)")
        }
    }
}
