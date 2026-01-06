import Foundation
import GRDB

struct SearchResult: Codable {
    let noteId: String
    let title: String
    let folder: String
    let snippet: String
    let score: Double
}

actor HybridSearchService {
    private let databaseService: DatabaseService
    private let embeddingService: EmbeddingService
    
    init(databaseService: DatabaseService, embeddingService: EmbeddingService) {
        self.databaseService = databaseService
        self.embeddingService = embeddingService
    }
    
    func search(query: String, limit: Int = 10) async throws -> [SearchResult] {
        try await databaseService.setup()
        
        let ftsResults = try await databaseService.search(query: query)
        
        let queryVector = await embeddingService.generateEmbedding(for: query)
        let allVectors = try await databaseService.fetchAllVectors()
        
        var vectorScores: [String: Double] = [:]
        if let queryVector = queryVector {
            let queryVecArray = queryVector.withUnsafeBytes { Array($0.bindMemory(to: Double.self)) }
            
            for (id, vectorData) in allVectors {
                let docVecArray = vectorData.withUnsafeBytes { Array($0.bindMemory(to: Double.self)) }
                let score = cosineSimilarity(queryVecArray, docVecArray)
                vectorScores[id] = score
            }
        }
        
        let k = 60.0
        var rrfScores: [String: Double] = [:]
        
        for (index, record) in ftsResults.enumerated() {
            let rankScore = 1.0 / (k + Double(index + 1))
            rrfScores[record.id, default: 0] += rankScore
        }
        
        let sortedVectors = vectorScores.sorted { $0.value > $1.value }
        for (index, item) in sortedVectors.enumerated() {
            let rankScore = 1.0 / (k + Double(index + 1))
            rrfScores[item.key, default: 0] += rankScore
        }
        
        let sortedRRF = rrfScores.sorted { $0.value > $1.value }.prefix(limit)
        
        var finalResults: [SearchResult] = []
        for (id, score) in sortedRRF {
            if let note = try await databaseService.getNote(id: id) {
                let snippet = String(note.markdownContent.prefix(200))
                finalResults.append(SearchResult(
                    noteId: note.id,
                    title: note.title,
                    folder: note.folder,
                    snippet: snippet,
                    score: score
                ))
            }
        }
        
        return finalResults
    }
    
    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dotProduct = 0.0
        var normA = 0.0
        var normB = 0.0
        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        if normA == 0 || normB == 0 { return 0 }
        return dotProduct / (sqrt(normA) * sqrt(normB))
    }
}
