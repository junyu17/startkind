import Foundation
import UserNotifications

@MainActor
final class RescueNotificationService {
    private let center: UNUserNotificationCenter
    private let disabled: Bool
    private let requestIdentifier = "startkind.rescue.restart"

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        self.disabled = StartKindRuntime.isTestRuntime
    }

    func scheduleRescue(after seconds: TimeInterval = 30 * 60) {
        guard !disabled else { return }
        Task {
            let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted == true else { return }
            center.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
            let content = UNMutableNotificationContent()
            content.title = L("rescue.notification.title")
            content.body = L("rescue.notification.body")
            content.sound = .default
            content.userInfo = ["url": "startkind://rescue"]
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, seconds), repeats: false)
            let request = UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    func cancelRescue() {
        center.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
    }
}
