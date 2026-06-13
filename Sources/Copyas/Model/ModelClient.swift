import Foundation

public protocol ModelClient: Sendable {
    func checkAvailability() throws
    func generate(
        transform: Transform,
        input: String,
        onPartial: (@Sendable (String) -> Void)?
    ) async throws -> String
}
