# MCP Server Layer

**Model Context Protocol server exposing 14 tools to AI clients.**

## SERVER ARCHITECTURE
| Component | Role |
|-----------|------|
| `BraindumpMCPServer` | Main server class (non-actor) |
| `14 Tool Handlers` | Each tool has `handle*` method |
| `Tool Definitions` | JSON schemas for all tools |

## TOOLS (14 TOTAL)
| Tool | Handler | Purpose |
|------|---------|---------|
| `notes_list` | `handleNotesList` | List all notes (optional folder filter) |
| `notes_get` | `handleNotesGet` | Get note by ID |
| `notes_create` | `handleNotesCreate` | Create new note |
| `notes_search` | `handleNotesSearch` | AppleScript search |
| `notes_delete` | `handleNotesDelete` | Delete note by ID |
| `notes_folders` | `handleNotesFolders` | List folders with counts |
| `reminders_list` | `handleRemindersList` | List reminders (optional list filter) |
| `reminders_get` | `handleRemindersGet` | Get reminder by ID |
| `reminders_create` | `handleRemindersCreate` | Create reminder |
| `reminders_complete` | `handleRemindersComplete` | Complete reminder |
| `reminders_delete` | `handleRemindersDelete` | Delete reminder |
| `reminders_search` | `handleRemindersSearch` | Search by title |
| `reminders_lists` | `handleRemindersLists` | List all reminder lists |
| `search_notes` | `handleSearchNotes` | **Hybrid search** (FTS5 + semantic) |

## DEPENDENCY INJECTION
```swift
init(
    notesService: NotesServiceProtocol,
    remindersService: RemindersServiceProtocol,
    databaseService: DatabaseService,
    embeddingService: EmbeddingService
)
```

## SCHEMA DEFINITIONS
- `BraindumpMCPServer.jsonSchema()` - Helper for JSON schemas
- Each tool has `name`, `description`, `properties`, `required`

## CONVENTIONS (DIFFERENT FROM PARENT)
- **All handlers return `JSONValue`** (not typed responses)
- **Services injected as protocols** (testability)
- **No actor isolation in server** (synchronous orchestration)

## ANTI-PATTERNS
- Never expose raw service types in public API
- Don't bypass JSON schema validation
- Don't use `as any` for type coercion
