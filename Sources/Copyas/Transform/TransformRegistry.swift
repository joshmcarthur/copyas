import Foundation

enum TransformRegistry {
    static func resolve(_ name: String) -> Transform? {
        Transform(rawValue: name.lowercased())
    }
}
