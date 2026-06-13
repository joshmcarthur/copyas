import Foundation

enum FoundationModelsErrorMapper {
    static func map(_ error: Error) -> GenerationError {
        if let generationError = error as? GenerationError {
            return generationError
        }

        if containsGuardrailViolation(error) {
            return .contentBlocked
        }

        if containsModelAssetFailure(error) {
            return .modelAssetsUnavailable
        }

        return .generationFailed(String(describing: error))
    }

    private static func containsGuardrailViolation(_ error: Error) -> Bool {
        let description = String(describing: error)
        guard description.contains("guardrailViolation") else {
            return false
        }

        return description.contains("sensitive")
            || description.contains("unsafe")
    }

    private static func containsModelAssetFailure(_ error: Error) -> Bool {
        visitErrors(error) { nsError in
            if nsError.domain == "com.apple.UnifiedAssetFramework", nsError.code == 5000 {
                return true
            }

            if nsError.domain.contains("ModelManagerError"),
               [1013, 1026].contains(nsError.code)
            {
                return true
            }

            if nsError.domain == "com.apple.SensitiveContentAnalysisML", nsError.code == 15 {
                return hasModelManagerFailure(in: nsError)
            }

            return false
        }
    }

    private static func hasModelManagerFailure(in error: NSError) -> Bool {
        visitErrors(error) { nsError in
            nsError.domain.contains("ModelManagerError")
                && [1013, 1026].contains(nsError.code)
        }
    }

    private static func visitErrors(_ error: Error, matches: (NSError) -> Bool) -> Bool {
        var queue: [Error] = [error]
        var visited = Set<ObjectIdentifier>()

        while let current = queue.popLast() {
            let identity = ObjectIdentifier(current as AnyObject)
            guard visited.insert(identity).inserted else {
                continue
            }

            let nsError = current as NSError
            if matches(nsError) {
                return true
            }

            if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
                queue.append(underlying)
            }

            if let underlyingErrors = nsError.userInfo[NSMultipleUnderlyingErrorsKey] as? [Error] {
                queue.append(contentsOf: underlyingErrors)
            }
        }

        return false
    }
}
