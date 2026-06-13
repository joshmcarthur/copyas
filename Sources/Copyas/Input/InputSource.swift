import AppKit
import Foundation

public struct InputSource: Sendable {
    var readsStdin: Bool
    var readStdin: @Sendable () throws -> Data
    var readClipboard: @Sendable () -> String?

    public static func live(readsStdin: Bool) -> InputSource {
        InputSource(
            readsStdin: readsStdin,
            readStdin: { FileHandle.standardInput.readDataToEndOfFile() },
            readClipboard: { NSPasteboard.general.string(forType: .string) }
        )
    }

    func readText() throws -> String {
        let rawText: String = if readsStdin {
            try String(decoding: readStdin(), as: UTF8.self)
        } else {
            readClipboard() ?? ""
        }

        let trimmed = rawText.trimmingTrailingWhitespaceAndNewlines()
        guard !trimmed.isEmpty else {
            throw GenerationError.noInput
        }

        return trimmed
    }
}

private extension String {
    func trimmingTrailingWhitespaceAndNewlines() -> String {
        var end = endIndex

        while end > startIndex {
            let previous = index(before: end)
            let scalars = self[previous].unicodeScalars

            guard scalars.allSatisfy({ CharacterSet.whitespacesAndNewlines.contains($0) }) else {
                break
            }

            end = previous
        }

        return String(self[..<end])
    }
}
