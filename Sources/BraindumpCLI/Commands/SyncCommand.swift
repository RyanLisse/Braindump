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
        
        let result = try await Spinner.withSpinner("Syncing notes", isEnabled: !json) {
            try await syncService.sync()
        }
        
        if json {
            let output: [String: Any] = [
                "processed": result.processed,
                "errors": result.errors
            ]
            let data = try JSONSerialization.data(withJSONObject: output, options: .prettyPrinted)
            print(String(data: data, encoding: .utf8)!)
        } else {
            print("\nSync complete:")
            print("  Processed: \(result.processed)")
            print("  Errors: \(result.errors)")
        }
    }
}
