import AppKit
import Copyas
import SwiftUI

struct MenuContentView: View {
    @Bindable var appState: AppState

    var body: some View {
        if let availabilityError = appState.availabilityError {
            MenuMessageView(message: availabilityError, style: .info)
            Divider()
        }

        ForEach(Transform.allCases, id: \.self) { transform in
            Button(TransformPresentation.menuTitle(for: transform)) {
                appState.transform(transform)
            }
            .disabled(!appState.transformsEnabled)
        }

        Divider()

        if appState.isRunning {
            MenuMessageView(message: "Transforming…", style: .info)
        }

        if let lastSuccess = appState.lastSuccess {
            MenuMessageView(message: lastSuccess, style: .success)
        }

        if let lastError = appState.lastError {
            MenuMessageView(title: "Could not transform", message: lastError, style: .error)
        }

        Divider()

        Button("Quit Copyas") {
            NSApplication.shared.terminate(nil)
        }
    }
}
