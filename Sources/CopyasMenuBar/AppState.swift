import AppKit
import Copyas
import Observation
import SwiftUI

@MainActor
@Observable
final class AppState {
    var isRunning = false
    var lastError: String?
    var lastSuccess: String?
    var availabilityError: String?

    var transformsEnabled: Bool {
        availabilityError == nil && !isRunning
    }

    private var currentTask: Task<Void, Never>?
    private let modelClient: any ModelClient
    private let environment: AppEnvironment
    private let notifications = NotificationService()

    init(modelClient: any ModelClient = LiveModelClient()) {
        self.modelClient = modelClient
        environment = AppEnvironment.clipboardOnly(modelClient: modelClient)
        Task {
            await setup()
        }
    }

    func transform(_ transform: Transform) {
        guard currentTask == nil else { return }

        lastError = nil
        lastSuccess = nil
        isRunning = true

        currentTask = Task { @MainActor in
            defer {
                isRunning = false
                currentTask = nil
            }

            do {
                _ = try await TransformExecutor.run(
                    transform: transform,
                    configuration: .clipboardOnly,
                    environment: environment
                )
                lastSuccess = TransformPresentation.successMessage(for: transform)
                await notifications.notifySuccess(transform: transform)
            } catch {
                lastError = userFacingDescription(for: error)
            }
        }
    }

    private func setup() async {
        do {
            try modelClient.checkAvailability()
            availabilityError = nil
            modelClient.prewarmAllTransforms()
        } catch {
            availabilityError = userFacingDescription(for: error)
        }
    }

    private func userFacingDescription(for error: Error) -> String {
        if let error = error as? GenerationError {
            return error.userFacingMessage
        }
        return error.localizedDescription
    }
}
