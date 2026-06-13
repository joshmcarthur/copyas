import Foundation

enum InputSuitability {
    static let minimumWordLength = 3

    static func validate(_ input: String) throws {
        guard longestAlphabeticToken(in: input) >= minimumWordLength else {
            throw GenerationError.unsuitableInput
        }
    }

    static func longestAlphabeticToken(in input: String) -> Int {
        input.split { !$0.isLetter }
            .map(\.count)
            .max() ?? 0
    }
}
