import ArgumentParser
import Foundation

struct Search: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search notes using hybrid FTS + semantic search"
    )
    
    @Argument(help: "Search query")
    var query: String
    
    @Option(name: .shortAndLong, help: "Maximum results to return")
    var limit: Int = 10
    
    @Flag(name: .shortAndLong, help: "Output as JSON")
    var json: Bool = false
    
    func run() async throws {
        let databaseService = DatabaseService()
        let embeddingService = EmbeddingService()
        
        let searchService = HybridSearchService(
            databaseService: databaseService,
            embeddingService: embeddingService
        )
        
        let results = try await Spinner.withSpinner("Searching local index", isEnabled: !json) {
            try await searchService.search(query: query, limit: limit)
        }
        
        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(results)
            print(String(data: data, encoding: .utf8)!)
        } else {
            if results.isEmpty {
                print("No results found for '\(query)'.")
                print("\nTip: Run 'braindump sync' first to index your notes.")
            } else {
                print("\nSearch results for '\(query)':\n")
                for (index, result) in results.enumerated() {
                    let scorePercent = Int(result.score * 100)
                    print("\(index + 1). \(result.title) [\(result.folder)]")
                    print("   Score: \(scorePercent)%")
                    let snippetPreview = result.snippet.replacingOccurrences(of: "\n", with: " ").prefix(80)
                    print("   \(snippetPreview)...")
                    print("")
                }
            }
        }
    }
}
