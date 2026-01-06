import Foundation

public final class Spinner: Sendable {
    private let message: String
    private let sequence = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    private let task: Task<Void, Never>
    
    public init(_ message: String) {
        self.message = message
        let sequence = self.sequence
        self.task = Task {
            var index = 0
            while !Task.isCancelled {
                let char = sequence[index % sequence.count]
                let output = "\r\(char) \(message)..."
                if let data = output.data(using: .utf8) {
                    try? FileHandle.standardError.write(contentsOf: data)
                }
                try? await Task.sleep(nanoseconds: 80_000_000)
                index += 1
            }
        }
    }
    
    public func stop() {
        task.cancel()
        // Clear the line on stderr using ANSI escape code
        if let data = "\r\u{1B}[K".data(using: .utf8) {
            try? FileHandle.standardError.write(contentsOf: data)
        }
    }
    
    /// Helper to run an async operation with a spinner.
    public static func withSpinner<T>(_ message: String, isEnabled: Bool = true, _ operation: @Sendable () async throws -> T) async throws -> T {
        guard isEnabled else { return try await operation() }
        let spinner = Spinner(message)
        defer { spinner.stop() }
        return try await operation()
    }
}
