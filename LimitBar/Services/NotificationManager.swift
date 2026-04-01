import Foundation
import UserNotifications

final class NotificationManager {
    func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func scheduleCooldownReadyNotification(accountName: String, at date: Date) {
        let timeInterval = date.timeIntervalSinceNow
        guard timeInterval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Account available again"
        content.body = "\(accountName) should be ready to use."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: timeInterval,
            repeats: false
        )

        let identifier = "cooldown-\(accountName.replacingOccurrences(of: " ", with: "-"))"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    func cancelNotification(for accountName: String) {
        let identifier = "cooldown-\(accountName.replacingOccurrences(of: " ", with: "-"))"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
