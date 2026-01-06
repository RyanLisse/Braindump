import Foundation
import GRDB

public struct NoteRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    var id: String
    var title: String
    var folder: String
    var markdownContent: String
    var rawHtml: String
    var modificationDate: Date?
    var vector: Data? // Serialized [Double]
    
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let title = Column(CodingKeys.title)
        static let markdownContent = Column(CodingKeys.markdownContent)
        static let modificationDate = Column(CodingKeys.modificationDate)
        static let vector = Column(CodingKeys.vector)
    }
}

struct SyncState: Codable, FetchableRecord, PersistableRecord {
    var key: String
    var value: String
}

public actor DatabaseService {
    private var dbWriter: DatabaseWriter?
    
    public init() {}
    
    private func getDatabasePath() throws -> String {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(".braindump")
        
        if !fileManager.fileExists(atPath: dir.path) {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        
        return dir.appendingPathComponent("braindump.sqlite").path
    }
    
    func setup() throws {
        let path = try getDatabasePath()
        let dbQueue = try DatabaseQueue(path: path)
        
        try dbQueue.write { db in
            // Create Note table
            try db.create(table: "noteRecord", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("title", .text).notNull()
                t.column("folder", .text).notNull()
                t.column("markdownContent", .text).notNull()
                t.column("rawHtml", .text).notNull()
                t.column("modificationDate", .datetime)
                t.column("vector", .blob)
            }
            
            // Create FTS5 virtual table
            try db.create(virtualTable: "noteRecord_fts", ifNotExists: true, using: FTS5()) { t in
                t.tokenizer = .porter()
                t.column("title")
                t.column("markdownContent")
                t.content = "noteRecord"
            }
            
            // Triggers to keep FTS index in sync with main table
            // Insert Trigger
            try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS noteRecord_ai AFTER INSERT ON noteRecord BEGIN
                INSERT INTO noteRecord_fts(rowid, title, markdownContent) VALUES (new.rowid, new.title, new.markdownContent);
            END;
            """)
            
            // Delete Trigger
            try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS noteRecord_ad AFTER DELETE ON noteRecord BEGIN
                INSERT INTO noteRecord_fts(noteRecord_fts, rowid, title, markdownContent) VALUES('delete', old.rowid, old.title, old.markdownContent);
            END;
            """)
            
            // Update Trigger
            try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS noteRecord_au AFTER UPDATE ON noteRecord BEGIN
                INSERT INTO noteRecord_fts(noteRecord_fts, rowid, title, markdownContent) VALUES('delete', old.rowid, old.title, old.markdownContent);
                INSERT INTO noteRecord_fts(rowid, title, markdownContent) VALUES (new.rowid, new.title, new.markdownContent);
            END;
            """)
            
            // Sync State table
            try db.create(table: "syncState", ifNotExists: true) { t in
                t.column("key", .text).primaryKey()
                t.column("value", .text).notNull()
            }
        }
        
        self.dbWriter = dbQueue
    }
    
    func saveNote(_ note: NoteRecord) throws {
        guard let dbWriter = dbWriter else { throw DatabaseError.notInitialized }
        try dbWriter.write { db in
            try note.save(db)
        }
    }
    
    func saveSyncState(key: String, value: String) throws {
        guard let dbWriter = dbWriter else { throw DatabaseError.notInitialized }
        try dbWriter.write { db in
            let state = SyncState(key: key, value: value)
            try state.save(db)
        }
    }
    
    func getSyncState(key: String) throws -> String? {
        guard let dbWriter = dbWriter else { throw DatabaseError.notInitialized }
        return try dbWriter.read { db in
            try SyncState.fetchOne(db, key: key)?.value
        }
    }
    
    func fetchAllVectors() throws -> [(id: String, vector: Data)] {
        guard let dbWriter = dbWriter else { throw DatabaseError.notInitialized }
        return try dbWriter.read { db in
            let rows = try Row.fetchCursor(db, sql: "SELECT id, vector FROM noteRecord WHERE vector IS NOT NULL")
            var results: [(String, Data)] = []
            while let row = try rows.next() {
                if let id = row["id"] as? String, let vector = row["vector"] as? Data {
                    results.append((id, vector))
                }
            }
            return results
        }
    }
    
    func getNote(id: String) throws -> NoteRecord? {
        guard let dbWriter = dbWriter else { throw DatabaseError.notInitialized }
        return try dbWriter.read { db in
            try NoteRecord.fetchOne(db, key: id)
        }
    }
    
    // FTS Search
    func search(query: String) throws -> [NoteRecord] {
        guard let dbWriter = dbWriter else { throw DatabaseError.notInitialized }
        return try dbWriter.read { db in
            // Use FTS5 pattern matching
            // Note: simple prefix search for now
            let pattern = FTS5Pattern(matchingAllTokensIn: query)
            if let pattern = pattern {
                 return try NoteRecord.fetchAll(db, sql: """
                    SELECT noteRecord.* FROM noteRecord
                    JOIN noteRecord_fts ON noteRecord_fts.rowid = noteRecord.rowid
                    WHERE noteRecord_fts MATCH ?
                    ORDER BY rank
                    """, arguments: [pattern])
            } else {
                return []
            }
        }
    }
}

enum DatabaseError: Error {
    case notInitialized
}
