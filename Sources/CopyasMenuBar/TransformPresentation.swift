import Copyas

enum TransformPresentation {
    static func menuTitle(for transform: Transform) -> String {
        switch transform {
        case .summary:
            "Summary"
        case .markdown:
            "Markdown"
        case .pirate:
            "Pirate"
        }
    }

    static func successMessage(for transform: Transform) -> String {
        "Copied as \(menuTitle(for: transform))"
    }
}
