// Algorithm ported from LangChain RecursiveCharacterTextSplitter.
// Canonical source: https://github.com/langchain-ai/langchain/blob/master/libs/text-splitters/langchain_text_splitters/character.py

import Foundation

public struct RecursiveCharacterTextSplitter: Sendable {
    private let config: SplitConfig
    private let lengthFunction: TextLengthFunction

    public init(
        config: SplitConfig,
        lengthFunction: @escaping TextLengthFunction = TextLengthFunctions.characterCount
    ) {
        self.config = config
        self.lengthFunction = lengthFunction
    }

    public func split(text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        return splitText(text, separators: config.separators)
    }

    private func splitText(_ text: String, separators: [String]) -> [String] {
        var finalChunks: [String] = []
        var separator = separators.last ?? ""
        var newSeparators: [String] = []

        for (index, candidate) in separators.enumerated() {
            if candidate.isEmpty {
                separator = candidate
                break
            }
            if text.contains(candidate) {
                separator = candidate
                newSeparators = Array(separators.dropFirst(index + 1))
                break
            }
        }

        let splits = splitWithSeparator(
            text,
            separator: separator,
            keepSeparator: config.keepSeparator
        )
        var goodSplits: [String] = []
        let mergeSeparator = config.keepSeparator ? "" : separator

        for piece in splits {
            if lengthFunction(piece) < config.chunkSize {
                goodSplits.append(piece)
            } else {
                if !goodSplits.isEmpty {
                    finalChunks.append(contentsOf: mergeSplits(
                        goodSplits,
                        separator: mergeSeparator
                    ))
                    goodSplits = []
                }
                if newSeparators.isEmpty {
                    finalChunks.append(piece)
                } else {
                    finalChunks.append(contentsOf: splitText(piece, separators: newSeparators))
                }
            }
        }

        if !goodSplits.isEmpty {
            finalChunks.append(contentsOf: mergeSplits(goodSplits, separator: mergeSeparator))
        }

        return finalChunks.filter { !$0.isEmpty }
    }

    /// Port of LangChain `_split_text_with_regex` with `keep_separator=True` (start mode).
    private func splitWithSeparator(
        _ text: String,
        separator: String,
        keepSeparator: Bool
    ) -> [String] {
        guard !separator.isEmpty else {
            return text.map(String.init).filter { !$0.isEmpty }
        }

        if !keepSeparator {
            return text.components(separatedBy: separator).filter { !$0.isEmpty }
        }

        var tokens: [String] = []
        var remaining = text[...]
        while let range = remaining.range(of: separator) {
            tokens.append(String(remaining[..<range.lowerBound]))
            tokens.append(String(separator))
            remaining = remaining[range.upperBound...]
        }
        tokens.append(String(remaining))

        guard let first = tokens.first else { return [] }

        var paired: [String] = []
        if tokens.count >= 2 {
            var index = 1
            while index + 1 < tokens.count {
                paired.append(tokens[index] + tokens[index + 1])
                index += 2
            }
            if tokens.count.isMultiple(of: 2) {
                paired.append(tokens[tokens.count - 1])
            }
        }

        return ([first] + paired).filter { !$0.isEmpty }
    }

    /// Port of LangChain `TextSplitter._merge_splits`.
    private func mergeSplits(_ splits: [String], separator: String) -> [String] {
        let separatorLength = lengthFunction(separator)
        var docs: [String] = []
        var currentDoc: [String] = []
        var total = 0

        for piece in splits {
            let pieceLength = lengthFunction(piece)
            let separatorCost = currentDoc.isEmpty ? 0 : separatorLength
            if total + pieceLength + separatorCost > config.chunkSize {
                if !currentDoc.isEmpty {
                    if let doc = joinDocs(currentDoc, separator: separator) {
                        docs.append(doc)
                    }
                    while total > config.chunkOverlap
                        || (
                            total + pieceLength + (currentDoc.isEmpty ? 0 : separatorLength) >
                                config.chunkSize
                                && total > 0
                        )
                    {
                        let removedLength = lengthFunction(currentDoc[0])
                        let nextSeparatorCost = currentDoc.count > 1 ? separatorLength : 0
                        total -= removedLength + nextSeparatorCost
                        currentDoc.removeFirst()
                    }
                }
            }
            currentDoc.append(piece)
            total += pieceLength + (currentDoc.count > 1 ? separatorLength : 0)
        }

        if let doc = joinDocs(currentDoc, separator: separator) {
            docs.append(doc)
        }
        return docs
    }

    private func joinDocs(_ docs: [String], separator: String) -> String? {
        let text = docs.joined(separator: separator).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}
