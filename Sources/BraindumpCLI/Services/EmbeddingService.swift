import Foundation
import NaturalLanguage

public actor EmbeddingService {
    private var embedding: NLEmbedding?
    
    public init() {}
    
    func generateEmbedding(for text: String) -> Data? {
        if embedding == nil {
            embedding = NLEmbedding.sentenceEmbedding(for: .english)
        }
        
        guard let vector = embedding?.vector(for: text) else {
            return nil
        }
        
        // Serialize [Double] to Data
        return vector.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
    }
}
