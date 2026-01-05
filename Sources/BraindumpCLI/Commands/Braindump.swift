import ArgumentParser
import Foundation

public struct Braindump: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "braindump",
        abstract: "A macOS CLI & MCP server for Apple Notes and Reminders - dump your brain, not your productivity",
        version: "1.0.0",
        subcommands: [
            Notes.self,
            Reminders.self,
            MCP.self,
        ]
    )
    
    public init() {}
}

public struct GlobalOptions: ParsableArguments {
    @Flag(name: .shortAndLong, help: "Output in JSON format")
    public var json: Bool = false
    
    public init() {}
}
