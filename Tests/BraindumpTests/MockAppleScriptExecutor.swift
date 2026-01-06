import Foundation
import BraindumpCLI

public actor MockAppleScriptExecutor: AppleScriptExecutorProtocol {
    public var mockResult: String = ""
    public var mockError: Error?
    public var lastScript: String?
    
    public init() {}
    
    public func setMockResult(_ result: String) {
        self.mockResult = result
    }
    
    public func run(_ script: String) async throws -> String {
        self.lastScript = script
        if let error = mockError {
            throw error
        }
        return mockResult
    }
}
