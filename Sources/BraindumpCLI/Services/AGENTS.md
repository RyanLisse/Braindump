# Services Layer

**Actor-based business logic for Apple integration.**

## ACTORS (Thread-Safe)
| Service | Purpose | Dependencies |
|---------|---------|--------------|
| `NotesService` | Notes.app via AppleScript | AppleScriptRunner |
| `RemindersService` | Reminders.app via AppleScript | AppleScriptRunner, EventKit |
| `EventKitRemindersService` | Native EventKit Reminders | EventKit (faster) |
| `DatabaseService` | SQLite + FTS5 + vectors | GRDB.swift |
| `EmbeddingService` | NaturalLanguage embeddings | ML frameworks |
| `NotesSyncService` | Sync Notes → DB | NotesService, DatabaseService |
| `HybridSearchService` | FTS5 + RRF + semantic | DatabaseService, EmbeddingService |
| `HTMLConverterService` | HTML → Markdown | JavaScriptCore + turndown.js |

## DATA FLOW
```
Notes.app → NotesService (AppleScript) → HTMLConverterService → NotesSyncService → DatabaseService (SQLite/FTS5)
Reminders.app → RemindersService (AppleScript) OR EventKitRemindersService (native)
```

## CONVENTIONS (DIFFERENT FROM PARENT)
- **All services are Actors** (isolated state, `await` required)
- **Dependency Injection** via initializers (no singletons)
- **Protocol conformance** for testability (MockAppleScriptExecutor, etc.)

## ANTI-PATTERNS
- Never call `.performBlock` or `.sync` on Actors
- AppleScript strings constructed in-services (not external files)
- Don't use `as any` for type coercion

## KEY PATTERNS
- `AppleScriptRunner`: Executes `osascript` with pipe-delimited parsing
- `IDResolver`: Flexible reminder ID resolution (index, UUID, fuzzy title)
- `EventKitRemindersService`: Native EventKit fallback for Reminders (faster)
