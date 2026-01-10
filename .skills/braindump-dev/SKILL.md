---
name: braindump-dev
description: Develop and extend the Braindump macOS CLI and MCP server. Use when adding CLI commands, MCP tools, service actors, or tests for Apple Notes/Reminders integration.
---

# Braindump Development

Add CLI commands, MCP tools, service actors, and tests for the Apple Notes/Reminders CLI and MCP server.

## Quick Start

**To add a CLI command:**
1. Create struct in `Sources/BraindumpCLI/Commands/`
2. Register in `Braindump.swift` subcommands array
3. Add `--json` flag support

**To add an MCP tool:**
1. Define `Tool` in `MCP/BraindumpMCPServer.swift` `mcpTools` array
2. Add handler case in `handleToolCall` switch
3. Implement `handleToolName` method returning `JSONValue`

**To add a service actor:**
1. Define protocol in `Interfaces/`
2. Create actor in `Services/` with `AppleScriptExecutorProtocol` injection
3. Implement pipe-delimited AppleScript parsing

**To add tests:**
1. Create `[Service]Tests.swift` in `Tests/BraindumpTests/`
2. Use `MockAppleScriptExecutor` actor for mocking

## Add CLI Command

### Template (copy and customize)
```swift
import ArgumentParser

struct MyCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "my-action",
        abstract: "Does something useful"
    )
    
    @Argument(help: "Input value")
    var input: String
    
    @Option(name: .shortAndLong, help: "Option description")
    var option: String = "default"
    
    @Flag(name: .shortAndLong, help: "Output as JSON")
    var json: Bool = false
    
    func run() async throws {
        let service = MyService()
        
        let result = try await Spinner.withSpinner("Processing", isEnabled: !json) {
            try await service.performAction(input: input, option: option)
        }
        
        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(result)
            print(String(data: data, encoding: .utf8)!)
        } else {
            print("Result: \(result.description)")
        }
    }
}
```

### Register in Braindump.swift
```swift
public struct Braindump: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        subcommands: [
            Notes.self,
            Reminders.self,
            Sync.self,
            Search.self,
            MCP.self,
            MyCommand.self,  // Add here
        ]
    )
}
```

### Key Patterns
- Use `AsyncParsableCommand` for actor service calls
- Use `@Argument` for positional, `@Option` for named, `@Flag` for boolean
- Wrap AppleScript/DB ops in `Spinner.withSpinner("message") { }`
- Always include `--json` flag with standard output pattern

## Add MCP Tool

### Template (copy and customize)
```swift
// 1. Add to mcpTools array in BraindumpMCPServer.swift
Tool(
    name: "my_tool",
    description: "Does something useful",
    inputSchema: jsonSchema(properties: [
        "param1": stringProp("First parameter"),
        "param2": intProp("Second parameter")
    ], required: ["param1"])
)

// 2. Add case in handleToolCall switch
switch toolName {
    case "my_tool": return try await handleMyTool(args: args)
    // ... existing cases
}

// 3. Implement handler
private func handleMyTool(args: [String: JSONValue]) async throws -> CallTool.Result {
    guard case .string(let param1) = args["param1"] else {
        throw BraindumpMCPError.invalidParams("param1 required")
    }
    let param2 = (args["param2"]).flatMap { case .number(let n) in Int(n) }
    
    let result = try await myService.doSomething(param1: param1, param2: param2)
    
    return CallTool.Result(content: [.text(toJSON(result))])
}
```

### JSON Schema Helpers
- `jsonSchema(properties:required:)` - Base schema
- `stringProp(description:)` - String property
- `intProp(description:)` - Integer property
- `boolProp(description:)` - Boolean property

## Add Service Actor

### Template (copy and customize)
```swift
// 1. Define protocol in Interfaces/
public protocol MyServiceProtocol {
    func doSomething(input: String) async throws -> MyResult
}

// 2. Implement actor in Services/
public actor MyService: MyServiceProtocol {
    private let executor: any AppleScriptExecutorProtocol
    
    public init(executor: any AppleScriptExecutorProtocol = AppleScriptRunner()) {
        self.executor = executor
    }
    
    public func doSomething(input: String) async throws -> MyResult {
        let script = """
        tell application "TargetApp"
            do something with "\(input.escaped)"
        end tell
        """
        
        let output = try await executor.run(script)
        return parseOutput(output)
    }
    
    private func parseOutput(_ output: String) -> MyResult {
        // Parse pipe-delimited output
        let parts = output.split(separator: "|", maxSplits: 2)
        guard parts.count >= 2 else { throw MyError.parseError }
        return MyResult(field1: String(parts[0]), field2: String(parts[1]))
    }
}

// 3. Use in CLI/MCP with dependency injection
let service = MyService(executor: mockExecutor)  // Test
let service = MyService()  // Production
```

### Key Patterns
- Declare as `actor` for thread-safe AppleScript access
- Use protocol for testability (inject `AppleScriptExecutorProtocol`)
- Use `padZero` AppleScript helper for dates
- Escape double quotes: `.replacingOccurrences(of: "\"", with: "\\\"")`
- Use pipe-delimited parsing: `output.split(separator: "|")`

### AppleScript Date Helper
```applescript
on padZero(n)
    if n < 10 then
        return "0" & n
    else
        return n as string
    end if
end padZero
```

## Add Tests

### Template (copy and customize)
```swift
import Testing
import Foundation
@testable import BraindumpCLI

@Suite("MyService Tests")
struct MyServiceTests {
    
    @Test("method parses output correctly")
    func methodParsesOutput() async throws {
        let mockExecutor = MockAppleScriptExecutor()
        await mockExecutor.setMockResult("field1|field2|field3")
        
        let service = MyService(executor: mockExecutor)
        let result = try await service.doSomething(input: "test")
        
        #expect(result.field1 == "field1")
        #expect(result.field2 == "field2")
    }
    
    @Test("method handles empty output")
    func methodHandlesEmptyOutput() async throws {
        let mockExecutor = MockAppleScriptExecutor()
        await mockExecutor.setMockResult("")
        
        let service = MyService(executor: mockExecutor)
        let result = try await service.doSomething(input: "test")
        
        #expect(result.isEmpty)
    }
}
```

### Test Patterns
- Use `@Suite("Name")` struct for grouping
- Use `@Test("Description")` for test functions
- Use `#expect(condition)` for assertions
- Use `MockAppleScriptExecutor` actor for AppleScript mocking
- Inject mock via `init(executor:)` initializer

## Anti-Patterns

- **Never** use `as any`, `as?`, or unsafe casts
- **Never** call `.performBlock` or `.sync` on actors (use `await`)
- **Never** fetch items in loops (use bulk AppleScript with `whose` clause)
- **Never** expose raw service types in MCP public API (return `JSONValue`)
- **Never** put AppleScript in external files (keep in services)

## Directory Structure

```
Sources/BraindumpCLI/
├── Commands/          # CLI command implementations
├── Services/          # Actor-based business logic
├── Interfaces/        # Protocol definitions
├── MCP/              # MCP server and tools
├── Resources/        # JavaScript resources (turndown.js)
└── UI/               # CLI utilities (Spinner)

Tests/BraindumpTests/
├── [Service]Tests.swift
└── MockAppleScriptExecutor.swift
```

## Build & Test

```bash
swift build
swift test
swift run braindump --help
```
