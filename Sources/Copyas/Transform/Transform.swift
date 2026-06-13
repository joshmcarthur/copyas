import Foundation

public enum Transform: String, CaseIterable, Equatable, Sendable {
    case summary
    case markdown
    case pirate

    private static let refusalInstructions = """
    Only transform meaningful natural language from the input. If the input cannot be handled—such as bare IDs, hashes, codes, random tokens, numbers-only strings, or text too fragmentary to transform—do not guess or invent content. Output exactly this single line and nothing else:
    __COPYAS_REFUSE__
    """

    var instructions: String {
        switch self {
        case .summary:
            """
            \(Self.refusalInstructions)

            Summarise the following text as a short list of bullet points. Use `-` for bullets. Preserve factual accuracy. Do not add information that is not in the source. Output only the summary, no preamble.
            """
        case .markdown:
            """
            \(Self.refusalInstructions)

            Convert the following text into well-structured Markdown. Use headings, lists, and emphasis where appropriate. Preserve all factual content. Do not wrap the entire response in a markdown code fence. Preserve links and code snippets from the source when present. Output only the Markdown, no preamble.
            """
        case .pirate:
            """
            \(Self.refusalInstructions)

            Rewrite the following text in exaggerated pirate speak. Keep the original meaning and approximate length. Output only the rewritten text, no preamble.
            """
        }
    }
}
