public protocol AppleScriptExecutorProtocol: Sendable {
    func run(_ script: String) async throws -> String
}
