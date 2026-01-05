import ArgumentParser
import Foundation

struct MCP: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Start the MCP (Model Context Protocol) server for AI agents",
        subcommands: [
            Serve.self,
            Tools.self,
        ],
        defaultSubcommand: Serve.self
    )
}

struct Serve: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "serve",
        abstract: "Start the MCP server"
    )
    
    func run() async throws {
        let server = BraindumpMCPServer()
        try await server.run()
    }
}

struct Tools: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tools",
        abstract: "List available MCP tools"
    )
    
    @Flag(name: .shortAndLong, help: "Output in JSON format")
    var json: Bool = false
    
    func run() throws {
        let tools = BraindumpMCPServer.toolDefinitions
        
        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(tools)
            print(String(data: data, encoding: .utf8)!)
        } else {
            print("Available MCP Tools:")
            print("====================")
            for tool in tools {
                print("\n\(tool.name)")
                print("  \(tool.description)")
            }
        }
    }
}
