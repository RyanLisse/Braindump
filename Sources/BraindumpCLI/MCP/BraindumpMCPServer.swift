import Foundation
import MCP

public actor BraindumpMCPServer {
    private var server: Server?
    private let notesService: NotesService
    private let remindersService: RemindersService
    private let databaseService: DatabaseService
    private let embeddingService: EmbeddingService
    
    public init(
        notesService: NotesService = NotesService(),
        remindersService: RemindersService = RemindersService(),
        databaseService: DatabaseService = DatabaseService(),
        embeddingService: EmbeddingService = EmbeddingService()
    ) {
        self.notesService = notesService
        self.remindersService = remindersService
        self.databaseService = databaseService
        self.embeddingService = embeddingService
    }
    
    public func run() async throws {
        let transport = StdioTransport()
        
        let capabilities = Server.Capabilities(
            tools: .init(listChanged: false)
        )
        
        let server = Server(
            name: "braindump",
            version: "1.0.0",
            capabilities: capabilities
        )
        self.server = server
        
        await server.withMethodHandler(ListTools.self) { _ in
            ListTools.Result(tools: Self.mcpTools)
        }
        
        await server.withMethodHandler(CallTool.self) { [weak self] params in
            guard let self = self else {
                throw BraindumpMCPError.internalError("Server not initialized")
            }
            return try await self.handleToolCall(params)
        }
        
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }
    
    private func handleToolCall(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        let toolName = params.name
        let args = params.arguments ?? [:]
        
        switch toolName {
        case "notes_list":
            return try await handleNotesList(args)
        case "notes_get":
            return try await handleNotesGet(args)
        case "notes_create":
            return try await handleNotesCreate(args)
        case "notes_search":
            return try await handleNotesSearch(args)
        case "notes_delete":
            return try await handleNotesDelete(args)
        case "notes_folders":
            return try await handleNotesFolders()
        case "reminders_list":
            return try await handleRemindersList(args)
        case "reminders_get":
            return try await handleRemindersGet(args)
        case "reminders_create":
            return try await handleRemindersCreate(args)
        case "reminders_complete":
            return try await handleRemindersComplete(args)
        case "reminders_delete":
            return try await handleRemindersDelete(args)
        case "reminders_search":
            return try await handleRemindersSearch(args)
        case "reminders_lists":
            return try await handleRemindersLists()
        case "search_notes":
            return try await handleSearchNotes(args)
        default:
            throw BraindumpMCPError.methodNotFound("Unknown tool: \(toolName)")
        }
    }
    
    private func handleNotesList(_ args: [String: Value]) async throws -> CallTool.Result {
        var folder: String? = nil
        if case .string(let f) = args["folder"] {
            folder = f
        }
        
        let notes = try await notesService.listNotes(folder: folder)
        return CallTool.Result(content: [.text(toJSON(notes))])
    }
    
    private func handleNotesGet(_ args: [String: Value]) async throws -> CallTool.Result {
        guard case .string(let id) = args["id"] else {
            throw BraindumpMCPError.invalidParams("Missing 'id' parameter")
        }
        
        guard let note = try await notesService.getNote(id: id) else {
            return CallTool.Result(content: [.text("{\"error\": \"Note not found\"}")])
        }
        
        return CallTool.Result(content: [.text(toJSON(note))])
    }
    
    private func handleNotesCreate(_ args: [String: Value]) async throws -> CallTool.Result {
        guard case .string(let title) = args["title"] else {
            throw BraindumpMCPError.invalidParams("Missing 'title' parameter")
        }
        
        var body = ""
        if case .string(let b) = args["body"] {
            body = b
        }
        
        var folder = "Notes"
        if case .string(let f) = args["folder"] {
            folder = f
        }
        
        let noteId = try await notesService.createNote(title: title, body: body, folder: folder)
        return CallTool.Result(content: [.text("{\"success\": true, \"id\": \"\(noteId)\"}")])
    }
    
    private func handleNotesSearch(_ args: [String: Value]) async throws -> CallTool.Result {
        guard case .string(let query) = args["query"] else {
            throw BraindumpMCPError.invalidParams("Missing 'query' parameter")
        }
        
        let notes = try await notesService.searchNotes(query: query)
        return CallTool.Result(content: [.text(toJSON(notes))])
    }
    
    private func handleNotesDelete(_ args: [String: Value]) async throws -> CallTool.Result {
        guard case .string(let id) = args["id"] else {
            throw BraindumpMCPError.invalidParams("Missing 'id' parameter")
        }
        
        try await notesService.deleteNote(id: id)
        return CallTool.Result(content: [.text("{\"success\": true}")])
    }
    
    private func handleNotesFolders() async throws -> CallTool.Result {
        let folders = try await notesService.listFolders()
        return CallTool.Result(content: [.text(toJSON(folders))])
    }
    
    private func handleRemindersList(_ args: [String: Value]) async throws -> CallTool.Result {
        var list: String? = nil
        if case .string(let l) = args["list"] {
            list = l
        }
        
        var includeCompleted = false
        if case .bool(let c) = args["include_completed"] {
            includeCompleted = c
        }
        
        let reminders = try await remindersService.listReminders(list: list, includeCompleted: includeCompleted)
        return CallTool.Result(content: [.text(toJSON(reminders))])
    }
    
    private func handleRemindersGet(_ args: [String: Value]) async throws -> CallTool.Result {
        guard case .string(let id) = args["id"] else {
            throw BraindumpMCPError.invalidParams("Missing 'id' parameter")
        }
        
        guard let reminder = try await remindersService.getReminder(id: id) else {
            return CallTool.Result(content: [.text("{\"error\": \"Reminder not found\"}")])
        }
        
        return CallTool.Result(content: [.text(toJSON(reminder))])
    }
    
    private func handleRemindersCreate(_ args: [String: Value]) async throws -> CallTool.Result {
        guard case .string(let title) = args["title"] else {
            throw BraindumpMCPError.invalidParams("Missing 'title' parameter")
        }
        
        var list = "Reminders"
        if case .string(let l) = args["list"] {
            list = l
        }
        
        var dueDate: Date? = nil
        if case .string(let dateStr) = args["due_date"] {
            let formatter = ISO8601DateFormatter()
            dueDate = formatter.date(from: dateStr)
        }
        
        var notes: String? = nil
        if case .string(let n) = args["notes"] {
            notes = n
        }
        
        var priority = 0
        if case .int(let p) = args["priority"] {
            priority = p
        }
        
        let reminderId = try await remindersService.createReminder(
            title: title,
            list: list,
            dueDate: dueDate,
            notes: notes,
            priority: priority
        )
        
        return CallTool.Result(content: [.text("{\"success\": true, \"id\": \"\(reminderId)\"}")])
    }
    
    private func handleRemindersComplete(_ args: [String: Value]) async throws -> CallTool.Result {
        guard case .string(let id) = args["id"] else {
            throw BraindumpMCPError.invalidParams("Missing 'id' parameter")
        }
        
        var undo = false
        if case .bool(let u) = args["undo"] {
            undo = u
        }
        
        if undo {
            try await remindersService.uncompleteReminder(id: id)
        } else {
            try await remindersService.completeReminder(id: id)
        }
        
        return CallTool.Result(content: [.text("{\"success\": true}")])
    }
    
    private func handleRemindersDelete(_ args: [String: Value]) async throws -> CallTool.Result {
        guard case .string(let id) = args["id"] else {
            throw BraindumpMCPError.invalidParams("Missing 'id' parameter")
        }
        
        try await remindersService.deleteReminder(id: id)
        return CallTool.Result(content: [.text("{\"success\": true}")])
    }
    
    private func handleRemindersSearch(_ args: [String: Value]) async throws -> CallTool.Result {
        guard case .string(let query) = args["query"] else {
            throw BraindumpMCPError.invalidParams("Missing 'query' parameter")
        }
        
        let reminders = try await remindersService.searchReminders(query: query)
        return CallTool.Result(content: [.text(toJSON(reminders))])
    }
    
    private func handleRemindersLists() async throws -> CallTool.Result {
        let lists = try await remindersService.listLists()
        return CallTool.Result(content: [.text(toJSON(lists))])
    }
    
    private func handleSearchNotes(_ args: [String: Value]) async throws -> CallTool.Result {
        guard case .string(let query) = args["query"] else {
            throw BraindumpMCPError.invalidParams("Missing 'query' parameter")
        }
        
        var limit = 10
        if case .int(let l) = args["limit"] {
            limit = l
        }
        
        let searchService = HybridSearchService(
            databaseService: databaseService,
            embeddingService: embeddingService
        )
        
        let results = try await searchService.search(query: query, limit: limit)
        return CallTool.Result(content: [.text(toJSON(results))])
    }
    
    private func toJSON<T: Codable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}

extension BraindumpMCPServer {
    private static func jsonSchema(properties: [String: Value], required: [String] = []) -> Value {
        var schema: [String: Value] = [
            "type": .string("object"),
            "properties": .object(properties)
        ]
        if !required.isEmpty {
            schema["required"] = .array(required.map { .string($0) })
        }
        return .object(schema)
    }
    
    private static func stringProp(_ desc: String) -> Value {
        .object(["type": .string("string"), "description": .string(desc)])
    }
    
    private static func boolProp(_ desc: String) -> Value {
        .object(["type": .string("boolean"), "description": .string(desc)])
    }
    
    private static func intProp(_ desc: String) -> Value {
        .object(["type": .string("integer"), "description": .string(desc)])
    }
    
    static var mcpTools: [Tool] {
        [
            Tool(
                name: "notes_list",
                description: "List all notes. Optional: folder to filter.",
                inputSchema: jsonSchema(properties: [
                    "folder": stringProp("Filter by folder name")
                ])
            ),
            Tool(
                name: "notes_get",
                description: "Get a note by ID.",
                inputSchema: jsonSchema(properties: [
                    "id": stringProp("Note ID")
                ], required: ["id"])
            ),
            Tool(
                name: "notes_create",
                description: "Create a new note.",
                inputSchema: jsonSchema(properties: [
                    "title": stringProp("Note title"),
                    "body": stringProp("Note body content"),
                    "folder": stringProp("Folder name (default: Notes)")
                ], required: ["title"])
            ),
            Tool(
                name: "notes_search",
                description: "Search notes by title or content.",
                inputSchema: jsonSchema(properties: [
                    "query": stringProp("Search query")
                ], required: ["query"])
            ),
            Tool(
                name: "notes_delete",
                description: "Delete a note by ID.",
                inputSchema: jsonSchema(properties: [
                    "id": stringProp("Note ID")
                ], required: ["id"])
            ),
            Tool(
                name: "notes_folders",
                description: "List all note folders with note counts.",
                inputSchema: jsonSchema(properties: [:])
            ),
            Tool(
                name: "reminders_list",
                description: "List reminders. Optional: filter by list.",
                inputSchema: jsonSchema(properties: [
                    "list": stringProp("Filter by list name"),
                    "include_completed": boolProp("Include completed reminders")
                ])
            ),
            Tool(
                name: "reminders_get",
                description: "Get a reminder by ID.",
                inputSchema: jsonSchema(properties: [
                    "id": stringProp("Reminder ID")
                ], required: ["id"])
            ),
            Tool(
                name: "reminders_create",
                description: "Create a new reminder.",
                inputSchema: jsonSchema(properties: [
                    "title": stringProp("Reminder title"),
                    "list": stringProp("List name (default: Reminders)"),
                    "due_date": stringProp("Due date in ISO8601 format"),
                    "notes": stringProp("Additional notes"),
                    "priority": intProp("Priority 0-9")
                ], required: ["title"])
            ),
            Tool(
                name: "reminders_complete",
                description: "Mark a reminder as completed.",
                inputSchema: jsonSchema(properties: [
                    "id": stringProp("Reminder ID"),
                    "undo": boolProp("Undo completion")
                ], required: ["id"])
            ),
            Tool(
                name: "reminders_delete",
                description: "Delete a reminder by ID.",
                inputSchema: jsonSchema(properties: [
                    "id": stringProp("Reminder ID")
                ], required: ["id"])
            ),
            Tool(
                name: "reminders_search",
                description: "Search reminders by title.",
                inputSchema: jsonSchema(properties: [
                    "query": stringProp("Search query")
                ], required: ["query"])
            ),
            Tool(
                name: "reminders_lists",
                description: "List all reminder lists with pending counts.",
                inputSchema: jsonSchema(properties: [:])
            ),
            Tool(
                name: "search_notes",
                description: "Search notes using hybrid FTS + semantic search. Run 'sync' first to index notes.",
                inputSchema: jsonSchema(properties: [
                    "query": stringProp("Search query"),
                    "limit": intProp("Maximum results to return (default: 10)")
                ], required: ["query"])
            ),
        ]
    }
}

public struct ToolDefinition: Codable {
    public let name: String
    public let description: String
}

extension BraindumpMCPServer {
    public static var toolDefinitions: [ToolDefinition] {
        mcpTools.map { ToolDefinition(name: $0.name, description: $0.description ?? "") }
    }
}

enum BraindumpMCPError: Error, LocalizedError {
    case internalError(String)
    case methodNotFound(String)
    case invalidParams(String)
    
    var errorDescription: String? {
        switch self {
        case .internalError(let msg): return "Internal error: \(msg)"
        case .methodNotFound(let msg): return "Method not found: \(msg)"
        case .invalidParams(let msg): return "Invalid parameters: \(msg)"
        }
    }
}
