# Refactoring Plan: Protocol-Based Architecture & EventKit

**Date:** 2026-01-06
**Status:** Draft

## Context
The current `Braindump` implementation couples logic with `AppleScriptRunner`, making TDD difficult. `RemindersService` uses slow AppleScript instead of the native `EventKit` framework. We need to refactor to a protocol-based architecture to enable testing and switch to `EventKit` for Reminders.

## Goals
1.  **Testability**: Decouple logic from execution (AppleScript/EventKit) to allow unit testing via mocks.
2.  **Performance**: Use `EventKit` for Reminders (faster, safer).
3.  **Features**: Enhance Apple Notes support with HTML parsing and Attachments (pending research).
4.  **Stability**: Use robust parsing logic instead of fragile text splitting.

## Architecture

### 1. Protocols (Service Layer)
We will define protocols to abstract the data source.

```swift
/// Abstract execution of AppleScript (for Notes)
public protocol AppleScriptExecutorProtocol: Sendable {
    func run(_ script: String) async throws -> String
}

/// Domain Interface for Notes
public protocol NotesServiceProtocol: Sendable {
    func listFolders() async throws -> [NoteFolder]
    func listNotes(folder: String?) async throws -> [Note]
    func getNote(id: String) async throws -> Note?
    func searchNotes(query: String) async throws -> [Note]
    func createNote(title: String, body: String, folder: String) async throws -> String
    // Future: Attachments
}

/// Domain Interface for Reminders
public protocol RemindersServiceProtocol: Sendable {
    func listLists() async throws -> [ReminderList]
    func listReminders(list: String?) async throws -> [Reminder]
    func createReminder(title: String, list: String?, dueDate: Date?) async throws -> String
    func completeReminder(id: String) async throws
}
```

### 2. Implementations

*   **`AppleScriptNotesService`**: Conforms to `NotesServiceProtocol`. Uses `AppleScriptExecutorProtocol` to run `osascript`.
*   **`EventKitRemindersService`**: Conforms to `RemindersServiceProtocol`. Uses `EKEventStore` directly.
*   **`MockNotesService` / `MockRemindersService`**: In-memory implementations for testing.

### 3. Dependency Injection
The `BraindumpMCPServer` and CLI Commands will accept these protocols in their initializers/setup.

## Implementation Steps

### Phase 1: Foundation (TDD)
- [ ] Define Protocols in `Sources/BraindumpCLI/Interfaces`.
- [ ] Create `AppleScriptExecutor` implementation and `MockAppleScriptExecutor`.
- [ ] Test: Write tests for `AppleScriptNotesService` parsing logic using the Mock executor.

### Phase 2: Reminders Refactor (EventKit)
- [ ] Create `EventKitRemindersService`.
- [ ] Add `NSAppleEventsUsageDescription` (if needed) and `NSRemindersUsageDescription` to `Info.plist` (or equivalent for CLI entitlements).
- [ ] Implement CRUD using `EventKit`.

### Phase 3: Notes Enhancements
- [ ] Integrate HTML parsing (SwiftSoup or Regex based on `demark` learnings).
- [ ] Add Attachment extraction logic.

### Phase 4: Integration
- [ ] Update `BraindumpMCPServer` to use the new services.
- [ ] Update CLI commands.
- [ ] Verify with MCP Inspector.

## Research Findings Integration
- **memo**: Will inform CLI UX and search patterns.
- **remindctl**: Will guide EventKit patterns (concurrency, error handling).
- **demark**: Will guide HTML -> Markdown conversion.
- **qmd / mcp-apple-notes**: Will guide efficient Notes appending/reading.

