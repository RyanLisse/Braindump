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
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                if process.terminationStatus != 0 {
                    let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: AppleScriptError.executionFailed(errorMessage))
                    return
                }
                
                let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                continuation.resume(returning: output)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    public func runIgnoringErrors(_ script: String) async -> String {
        do {
            return try await run(script)
        } catch {
            return ""
        }
    }
}
