import Copyas
import UserNotifications

@MainActor
final class NotificationService {
    private var didRequestAuthorization = false

    func notifySuccess(transform: Transform) async {
        if !didRequestAuthorization {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [
                .alert,
                .sound,
            ])
            didRequestAuthorization = true
        }

        let content = UNMutableNotificationContent()
        content.title = "Copyas"
        content.body = TransformPresentation.successMessage(for: transform)

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
