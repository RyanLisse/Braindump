# PROJECT KNOWLEDGE BASE

**Generated:** 2026-01-06
**Commit:** ed650cf
**Branch:** main

## OVERVIEW
Braindump is a macOS CLI and MCP server that bridges Apple Notes and Reminders via AppleScript. It allows AI agents and CLI users to manage notes and reminders using a unified interface, targeting macOS v26 (Tahoe). **Enhanced with hybrid search capabilities**: syncs Apple Notes to local SQLite database with FTS5 full-text search and NaturalLanguage embeddings for semantic similarity.

## STRUCTURE
```
.
├── Sources/
│   ├── BraindumpCLI/       # Main library (Commands, Services, MCP)
│   │   ├── Commands/       # CLI subcommands (Notes, Reminders, Sync, Search, MCP)
│   │   ├── Services/       # Business logic actors
│   │   ├── Interfaces/     # Protocol definitions
│   │   └── MCP/           # Model Context Protocol server
│   └── BraindumpExec/      # Executable entry point
├── Tests/                  # Unit tests
├── Package.swift           # SPM definition (macOS v26, Resources bundle)
└── Sources/BraindumpCLI/Resources/  # turndown.js for HTML→Markdown conversion
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| CLI Commands | `Sources/BraindumpCLI/Commands` | ArgumentParser implementations (`Braindump.swift` is root) |
| App Integration | `Sources/BraindumpCLI/Services` | `AppleScriptRunner` & Actor services |
| MCP Server | `Sources/BraindumpCLI/MCP` | Model Context Protocol implementation |
| Entry Point | `Sources/BraindumpExec/main.swift` | Runs the CLI |
| Database Schema | `Services/DatabaseService.swift` | SQLite with FTS5 + vector embeddings |
| Search Logic | `Services/HybridSearchService.swift` | RRF algorithm combining FTS5 + semantic search |

## CODE MAP
| Symbol | Type | Location | Role |
|--------|------|----------|------|
| `Braindump` | Struct | `Commands/Braindump.swift` | Root command, configures subcommands |
| `NotesService` | Actor | `Services/NotesService.swift` | Manages Notes.app via AppleScript |
| `RemindersService` | Actor | `Services/RemindersService.swift` | Manages Reminders.app via AppleScript |
| `BraindumpMCPServer` | Class | `MCP/BraindumpMCPServer.swift` | Exposes 14 tools to AI clients |
| `AppleScriptRunner` | Struct | `Services/AppleScriptRunner.swift` | Executes `osascript` commands |
| `IDResolver` | Struct | `Services/IDResolver.swift` | Flexible reminder ID resolution (index, UUID, fuzzy title) |
| `HTMLConverterService` | Actor | `Services/HTMLConverterService.swift` | HTML→Markdown via JavaScriptCore + turndown.js |
| `DatabaseService` | Actor | `Services/DatabaseService.swift` | SQLite persistence with GRDB.swift |
| `EmbeddingService` | Actor | `Services/EmbeddingService.swift` | NaturalLanguage embeddings for semantic search |
| `NotesSyncService` | Actor | `Services/NotesSyncService.swift` | Syncs Apple Notes → local DB with HTML→MD conversion |
| `HybridSearchService` | Actor | `Services/HybridSearchService.swift` | RRF algorithm combining FTS5 + vector similarity |
| `SyncCommand` | Struct | `Commands/SyncCommand.swift` | `braindump sync` - indexes notes to local database |
| `SearchCommand` | Struct | `Commands/SearchCommand.swift` | `braindump search` - hybrid search over indexed notes |

## CONVENTIONS
- **Concurrency**: Services (`NotesService`, `RemindersService`, etc.) are **Actors** to handle single-threaded operations safely.
- **Data Parsing**: Returns from AppleScript use pipe-delimited strings parsed by Swift services.
- **Dates**: Custom `padZero` AppleScript function + `ISO8601DateFormatter` used for date exchange.
- **JSON**: CLI commands support `--json` for machine-readable output.
- **Database**: SQLite stored at `~/.braindump/braindump.sqlite` with FTS5 virtual tables and vector embeddings.
- **Search**: Hybrid RRF (Reciprocal Rank Fusion) combines full-text search with semantic similarity.

## ANTI-PATTERNS (THIS PROJECT)
- **Direct AppleScript in Logic**: AppleScript strings are constructed within services; avoid moving this logic to external files unless necessary for complexity.
- **Blocking Calls**: Avoid blocking calls on the main thread; use `await` with actors.
- **Empty Schemas**: `BraindumpMCPServer` uses proper JSON schemas for all tools (14 total).
- **Type Suppression**: Never use `as any`, `@ts-ignore`, `@ts-expect-error` in Swift code.

## UNIQUE STYLES
- **Futuristic Targeting**: Explicitly targets macOS v26; ensure compatible APIs or placeholder checks.
- **Actor-Based Architecture**: All services are actors for safe concurrency.
- **Hybrid Search**: Combines traditional FTS5 with modern vector embeddings.

## COMMANDS
```bash
# Build
swift build

# Run CLI
swift run braindump --help
swift run braindump notes list
swift run braindump reminders list --json
swift run braindump sync                    # Index notes to local database
swift run braindump search "query"          # Hybrid search over indexed notes

# Run MCP Server
swift run braindump mcp

# Test
swift test
```

## NOTES
- **Dependencies**: Uses `swift-argument-parser`, `swift-sdk` (MCP), `GRDB.swift` (SQLite), `demark` (HTML→MD), `swift-log`.
- **Environment**: Requires macOS environment to execute AppleScript commands against real apps.
- **Database**: Stores at `~/.braindump/braindump.sqlite` with FTS5 indexes and vector embeddings.
- **Search Flow**: 1) `braindump sync` indexes notes with HTML→MD conversion + embeddings. 2) `braindump search` uses RRF to combine FTS5 + semantic results.
