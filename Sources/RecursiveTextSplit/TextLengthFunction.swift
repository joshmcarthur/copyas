import Foundation

/// Measures text length for chunk budgeting (character count or token count).
public typealias TextLengthFunction = @Sendable (String) -> Int

public enum TextLengthFunctions {
    public static let characterCount: TextLengthFunction = { $0.count }
}
