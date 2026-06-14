import SwiftUI

@main
struct CopyasMenuBarApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(appState: appState)
        } label: {
            Label(
                "Copyas",
                systemImage: appState.isRunning ? "arrow.triangle.2.circlepath" : "doc.on.clipboard"
            )
        }
    }
}
