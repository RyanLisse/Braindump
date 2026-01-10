# Commands Layer

**ArgumentParser implementations for CLI subcommands.**

## COMMAND STRUCTURE
| Command | File | Purpose |
|---------|------|---------|
| `notes` | `NotesCommand.swift` | Notes.app management (list, get, create, search, delete, folders) |
| `reminders` | `RemindersCommand.swift` | Reminders.app management (list, get, create, complete, delete, search, lists) |
| `sync` | `SyncCommand.swift` | Index notes to SQLite with FTS5 + embeddings |
| `search` | `SearchCommand.swift` | Hybrid search (FTS5 + semantic) |
| `mcp` | `MCPCommand.swift` | MCP server startup |
| `braindump` | `Braindump.swift` | Root command configuration |

## ARGUMENT PARSER PATTERNS
```swift
@Command
struct Notes: AsyncParsableCommand {
    @Option(name: .shortAndLong)
    var folder: String?

    @Flag
    var json: Bool = false

    mutating func run() async throws { ... }
}
```

## OUTPUT FORMATTING
- **Human**: Tabular output with columns
- **Machine**: `--json` flag returns typed JSON via `JSONValue`

## CONVENTIONS (DIFFERENT FROM PARENT)
- **AsyncParsableCommand**: All commands are async for actor service calls
- **Typed errors**: Use `BraindumpError` enum with exit codes
- **No business logic**: Commands only parse args → call services → format output

## ANTI-PATTERNS
- Don't embed AppleScript in command files
- Don't use `@Argument` for complex types (use `@Option` with parsing)
- Don't throw raw strings; throw `BraindumpError`
