# MCP Server Tools Reference

Braindump MCP server exposes 14 tools for managing Apple Notes and Reminders through AI assistants.

## Starting the Server

```bash
braindump mcp
```

The server runs on stdio by default, compatible with MCP clients.

## Tool Categories

- [Notes Tools](#notes-tools) (6 tools)
- [Reminders Tools](#reminders-tools) (7 tools)
- [Search Tools](#search-tools) (1 tool)

---

## Notes Tools

### notes_list

List all notes, optionally filtered by folder.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `folder` | string | No | Filter by folder name |

**Response:**
```json
{
  "notes": [
    {
      "id": "x-cored://...",
      "title": "Meeting Notes",
      "folder": "Work",
      "body": "...",
      "creationDate": "2026-01-06T10:00:00Z",
      "modificationDate": "2026-01-06T10:30:00Z"
    }
  ]
}
```

**Example:**
```json
{
  "name": "notes_list",
  "arguments": {
    "folder": "Personal"
  }
}
```

---

### notes_get

Get a specific note by ID.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Note ID |

**Response:**
```json
{
  "id": "x-cored://...",
  "title": "Meeting Notes",
  "folder": "Work",
  "body": "Discussion points...",
  "creationDate": "2026-01-06T10:00:00Z",
  "modificationDate": "2026-01-06T10:30:00Z"
}
```

**Example:**
```json
{
  "name": "notes_get",
  "arguments": {
    "id": "x-cored://ABC123..."
  }
}
```

---

### notes_create

Create a new note.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `title` | string | Yes | Note title |
| `body` | string | No | Note content (Markdown) |
| `folder` | string | No | Folder name (default: "Notes") |

**Response:**
```json
{
  "success": true,
  "id": "x-cored://..."
}
```

**Example:**
```json
{
  "name": "notes_create",
  "arguments": {
    "title": "New Idea",
    "body": "This is my new idea...",
    "folder": "Ideas"
  }
}
```

---

### notes_search

Search notes by title or content using AppleScript.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `query` | string | Yes | Search query |

**Response:**
```json
{
  "notes": [
    {
      "id": "x-cored://...",
      "title": "Matching Note",
      "folder": "Work",
      "body": "...",
      "creationDate": "...",
      "modificationDate": "..."
    }
  ]
}
```

**Example:**
```json
{
  "name": "notes_search",
  "arguments": {
    "query": "project timeline"
  }
}
```

---

### notes_delete

Delete a note by ID.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Note ID |

**Response:**
```json
{
  "success": true
}
```

**Example:**
```json
{
  "name": "notes_delete",
  "arguments": {
    "id": "x-cored://ABC123..."
  }
}
```

---

### notes_folders

List all note folders with note counts.

**Response:**
```json
{
  "folders": [
    {
      "name": "Notes",
      "noteCount": 25
    },
    {
      "name": "Work",
      "noteCount": 12
    }
  ]
}
```

**Example:**
```json
{
  "name": "notes_folders"
}
```

---

## Reminders Tools

### reminders_list

List reminders, optionally filtered by list.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `list` | string | No | Filter by list name |
| `include_completed` | boolean | No | Include completed (default: false) |

**Response:**
```json
{
  "reminders": [
    {
      "id": "x-apple-reminder://...",
      "title": "Buy groceries",
      "list": "Personal",
      "dueDate": "2026-01-07T09:00:00Z",
      "isCompleted": false,
      "notes": "Milk, Eggs",
      "priority": 5
    }
  ]
}
```

**Example:**
```json
{
  "name": "reminders_list",
  "arguments": {
    "list": "Personal",
    "include_completed": true
  }
}
```

---

### reminders_get

Get a specific reminder by ID.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Reminder ID |

**Response:**
```json
{
  "id": "x-apple-reminder://...",
  "title": "Buy groceries",
  "list": "Personal",
  "dueDate": "2026-01-07T09:00:00Z",
  "isCompleted": false,
  "notes": "Milk, Eggs",
  "priority": 5
}
```

**Example:**
{
  "name": "reminders_get",
  "arguments": {
    "id": "x-apple-reminder://ABC123..."
  }
}

---

### reminders_create

Create a new reminder.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `title` | string | Yes | Reminder title |
| `list` | string | No | List name (default: "Reminders") |
| `due_date` | string | No | Due date (ISO8601 format) |
| `notes` | string | No | Additional notes |
| `priority` | integer | No | Priority 0-9 (default: 0) |

**Response:**
```json
{
  "success": true,
  "id": "x-apple-reminder://..."
}
```

**Example:**
```json
{
  "name": "reminders_create",
  "arguments": {
    "title": "Finish report",
    "list": "Work",
    "due_date": "2026-01-15T17:00:00Z",
    "notes": "Chapter 3 review",
    "priority": 7
  }
}
```

---

### reminders_complete

Mark a reminder as completed (or uncomplete).

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Reminder ID |
| `undo` | boolean | No | Uncomplete instead (default: false) |

**Response:**
```json
{
  "success": true
}
```

**Example:**
```json
{
  "name": "reminders_complete",
  "arguments": {
    "id": "x-apple-reminder://ABC123..."
  }
}
```

---

### reminders_delete

Delete a reminder by ID.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Reminder ID |

**Response:**
```json
{
  "success": true
}
```

**Example:**
```json
{
  "name": "reminders_delete",
  "arguments": {
    "id": "x-apple-reminder://ABC123..."
  }
}
```

---

### reminders_search

Search reminders by title.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `query` | string | Yes | Search query |

**Response:**
```json
{
  "reminders": [
    {
      "id": "x-apple-reminder://...",
      "title": "Meeting with John",
      "list": "Work",
      "dueDate": "2026-01-08T14:00:00Z",
      "isCompleted": false,
      "notes": "",
      "priority": 3
    }
  ]
}
```

**Example:**
```json
{
  "name": "reminders_search",
  "arguments": {
    "query": "meeting"
  }
}
```

---

### reminders_lists

List all reminder lists with pending counts.

**Response:**
```json
{
  "lists": [
    {
      "name": "Personal",
      "count": 5
    },
    {
      "name": "Work",
      "count": 12
    }
  ]
}
```

**Example:**
```json
{
  "name": "reminders_lists"
}
```

---

## Search Tools

### search_notes

Hybrid search using FTS5 + semantic embeddings. **Run `braindump sync` first to index notes.**

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `query` | string | Yes | Search query |
| `limit` | integer | No | Max results (default: 10) |

**Response:**
```json
{
  "results": [
    {
      "id": "x-cored://...",
      "title": "Project Notes",
      "folder": "Work",
      "body": "...",
      "score": 0.85,
      "creationDate": "2026-01-05T10:00:00Z",
      "modificationDate": "2026-01-06T15:30:00Z"
    }
  ]
}
```

**Example:**
```json
{
  "name": "search_notes",
  "arguments": {
    "query": "project timeline and milestones",
    "limit": 5
  }
}
```

**Note:** This tool uses Reciprocal Rank Fusion (RRF) to combine:
- FTS5 full-text search results
- NaturalLanguage semantic similarity

---

## Error Handling

All tools return errors in standard MCP format:

```json
{
  "error": {
    "code": -32000,
    "message": "Failed to find note with id: ..."
  }
}
```

**Common Error Codes:**
- `-32000`: Internal error
- `-32601`: Method not found
- `-32602`: Invalid parameters

---

## See Also

- [README.md](README.md) - Main documentation
- [ARCHITECTURE.md](ARCHITECTURE.md) - Hybrid search architecture
- [AGENTS.md](AGENTS.md) - Developer documentation
