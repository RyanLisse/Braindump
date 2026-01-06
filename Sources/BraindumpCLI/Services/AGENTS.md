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

## DEVELOPER NOTES (FUTURE SELF)

### AppleScript Performance & Robustness
- **Bulk Fetching**: Never fetch notes in a loop. Spawning thousands of `osascript` processes is extremely slow and will appear to "hang". Use a single `fetchChangedNotes` call that filters by `modification date` in the `whose` clause and returns all properties (including body) pipe-delimited.
- **Robust Error Handling**: Always wrap AppleScript property access (`name of container`, etc.) in `try...on error` blocks. Some notes (like those in "Recently Deleted") will crash the script if you try to access certain properties.
- **Locale Independence**: AppleScript's `date` parsing is locale-dependent (e.g., "Monday" vs "Maandag"). To construct a reference date reliably, use:
  ```applescript
  set d to (current date)
  tell d to set {year, month, day, time} to {2001, 1, 1, 0}
  set d to d + secondsSince2001
  ```
- **Pipe Deadlocks**: When using `Process` to run `osascript`, always read `stdout` and `stderr` concurrently (using `async let`). Reading them sequentially can cause a deadlock if one pipe fills up while you are waiting for the other.
