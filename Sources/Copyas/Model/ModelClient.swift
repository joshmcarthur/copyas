import Foundation

public protocol ModelClient: Sendable {
    func checkAvailability() throws
    func generate(transform: Transform, input: String) async throws -> String
}
