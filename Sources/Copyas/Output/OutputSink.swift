import AppKit
import Foundation

public struct OutputSink: Sendable {
    var writesClipboard: Bool
    var writeStdout: @Sendable (String) -> Void
    var writeClipboard: @Sendable (String) -> Bool

    public static func live(
        writesClipboard: Bool,
        writeStdout: @escaping @Sendable (String) -> Void
    ) -> OutputSink {
        OutputSink(
            writesClipboard: writesClipboard,
            writeStdout: writeStdout,
            writeClipboard: { text in
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                return pasteboard.setString(text, forType: .string)
            }
        )
    }

    func writePartial(_ delta: String) {
        guard !writesClipboard, !delta.isEmpty else { return }
        writeStdout(delta)
    }

    func finalize(_ text: String) throws {
        guard !writesClipboard else { return }
        guard !text.hasSuffix("\n") else { return }
        writeStdout("\n")
    }

    func write(_ text: String) throws {
        if writesClipboard {
            guard writeClipboard(text) else {
                throw GenerationError.clipboardWriteFailed
            }
            return
        }

        let line = text.hasSuffix("\n") ? text : "\(text)\n"
        writeStdout(line)
    }
}
