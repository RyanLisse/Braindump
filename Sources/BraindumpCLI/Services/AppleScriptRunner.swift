import Foundation

public enum AppleScriptError: Error, LocalizedError {
    case executionFailed(String)
    case noOutput
    
    public var errorDescription: String? {
        switch self {
        case .executionFailed(let message): return "AppleScript failed: \(message)"
        case .noOutput: return "No output from AppleScript"
        }
    }
}

public struct AppleScriptRunner: AppleScriptExecutorProtocol, Sendable {
    public init() {}
    
    public func run(_ script: String) async throws -> String {
        let task = Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            try process.run()

            let outputData = try await outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = try await errorPipe.fileHandleForReading.readDataToEndOfFile()

            process.waitUntilExit()

            return (process.terminationStatus, outputData, errorData)
        }

        let (status, outputData, errorData) = try await task.value

        if status != 0 {
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw AppleScriptError.executionFailed(errorMessage)
        }

        return String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    public func runIgnoringErrors(_ script: String) async -> String {
        do {
            return try await run(script)
        } catch {
            return ""
        }
    }
}
