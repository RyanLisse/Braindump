# Hybrid Search Architecture

Braindump's hybrid search combines traditional full-text search with modern semantic embeddings using the Reciprocal Rank Fusion (RRF) algorithm.

## System Overview

```
Apple Notes
     │
     ▼
┌─────────────────┐
│  NotesService   │  ← AppleScript integration
│  (Actor)        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ HTMLConverter   │  ← HTML → Markdown via turndown.js
│ Service (Actor) │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ NotesSyncService│  ← Sync notes to local DB
│    (Actor)      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ DatabaseService │  ← SQLite + FTS5 + vectors
│    (Actor)      │
└────────┬────────┘
         │
         ▼
   ┌────┴────┐
   │  FTS5   │  ← Full-text search
   └────┬────┘
         │
   ┌────┴────┐
   │ Embedding│  ← NaturalLanguage embeddings
   │ Service  │
   └────┬────┘
         │
         ▼
┌─────────────────────────────────┐
│   HybridSearchService (Actor)   │
│   RRF Algorithm                 │
│   FTS5 + Semantic Fusion        │
└─────────────────────────────────┘
```

## Components

### DatabaseService (Actor)

SQLite persistence with GRDB.swift.

**Tables:**
- `notes` - Sync'd notes with markdown content
- `notes_fts` - FTS5 virtual table for full-text search
- `embeddings` - Vector embeddings for semantic similarity

**Location:** `Services/DatabaseService.swift`

### EmbeddingService (Actor)

NaturalLanguage framework for sentence embeddings.

**Features:**
- Generates embeddings for note content
- Computes cosine similarity for semantic search
- Uses Apple's ML frameworks (no external dependencies)

**Location:** `Services/EmbeddingService.swift`

### NotesSyncService (Actor)

Orchestrates the sync pipeline:

1. Fetches notes via `NotesService`
2. Converts HTML to Markdown via `HTMLConverterService`
3. Generates embeddings via `EmbeddingService`
4. Persists to `DatabaseService`

**Location:** `Services/NotesSyncService.swift`

### HybridSearchService (Actor)

Implements Reciprocal Rank Fusion algorithm.

```swift
// RRF formula: RRF(d) = 1 / (k + rank(d))
// k = 60 (standard constant)
// Combined score = α × RRF_fts + (1-α) × RRF_semantic
```

**Steps:**
1. Execute FTS5 query → get ranked results
2. Execute semantic search → get similarity scores
3. Fuse rankings using RRF
4. Return combined results sorted by fusion score

**Location:** `Services/HybridSearchService.swift`

### HTMLConverterService (Actor)

HTML to Markdown conversion using JavaScriptCore + turndown.js.

**Location:** `Services/HTMLConverterService.swift`

## Search Flow

### Sync Pipeline

```bash
braindump sync
```

1. `SyncCommand` calls `NotesSyncService.sync()`
2. Fetches all notes from Apple Notes via AppleScript
3. Converts HTML body to Markdown
4. Generates embeddings for each note
5. Stores in SQLite with FTS5 and vector indexes

### Search Pipeline

```bash
braindump search "meeting agenda"
```

1. `SearchCommand` calls `HybridSearchService.hybridSearch(query)`
2. **FTS5 Query**: Matches tokens in note content
3. **Semantic Query**: Finds semantically similar notes
4. **RRF Fusion**: Combines both result lists
5. Returns sorted results with relevance scores

## Database Schema

```sql
-- Notes table
CREATE TABLE notes (
    id TEXT PRIMARY KEY,
    title TEXT,
    folder TEXT,
    body TEXT,           -- Markdown content
    creationDate TEXT,
    modificationDate TEXT
);

-- FTS5 virtual table
CREATE VIRTUAL TABLE notes_fts USING fts5(content, tokenize='unicode61');

-- Embeddings table
CREATE TABLE embeddings (
    noteId TEXT PRIMARY KEY,
    embedding BLOB
);
```

## Performance Considerations

| Operation | Performance |
|-----------|-------------|
| Sync (100 notes) | ~5-10 seconds |
| FTS5 query | <10ms |
| Semantic query | ~50-100ms |
| RRF fusion | <5ms |

**Optimizations:**
- Embeddings generated asynchronously during sync
- FTS5 uses unicode61 tokenizer (multilingual support)
- RRF uses constant k=60 (optimal for most use cases)

## Dependencies

- **GRDB.swift**: SQLite with FTS5 support
- **NaturalLanguage**: Apple's ML framework for embeddings
- **JavaScriptCore + turndown.js**: HTML to Markdown conversion

## See Also

- [README.md](README.md) - Main documentation
- [MCP.md](MCP.md) - MCP server tools reference
- [AGENTS.md](AGENTS.md) - Developer documentation
