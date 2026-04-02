import Foundation
import UserNotifications

protocol UserNotificationCentering: AnyObject, Sendable {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

protocol NotificationScheduling: AnyObject {
    func requestAuthorization() async -> Bool
    func scheduleCooldownReadyNotification(accountName: String, at date: Date)
    func cancelNotification(for accountName: String)
}

private actor NotificationAuthorizationCoordinator {
    private enum State {
        case idle
        case requesting(Task<Bool, Never>)
        case authorized
        case denied
    }

    private let center: any UserNotificationCentering
    private var state: State = .idle

    init(center: any UserNotificationCentering) {
        self.center = center
    }

    func requestAuthorization() async -> Bool {
        switch state {
        case .authorized:
            return true
        case .denied:
            return false
        case .requesting(let task):
            return await task.value
        case .idle:
            let task = Task { [center] in
                (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            }
            state = .requesting(task)
            let granted = await task.value
            state = granted ? .authorized : .denied
            return granted
        }
    }

    func scheduleCooldownReadyNotification(accountName: String, at date: Date) async {
        guard await requestAuthorization() else { return }
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
        try? await center.add(request)
    }
}

final class NotificationManager {
    private let center: any UserNotificationCentering
    private let authorizationCoordinator: NotificationAuthorizationCoordinator

    init(center: any UserNotificationCentering = UNUserNotificationCenter.current()) {
        self.center = center
        self.authorizationCoordinator = NotificationAuthorizationCoordinator(center: center)
    }

    func requestAuthorization() async -> Bool {
        await authorizationCoordinator.requestAuthorization()
    }

    func scheduleCooldownReadyNotification(accountName: String, at date: Date) {
        Task { [authorizationCoordinator, accountName, date] in
            await authorizationCoordinator.scheduleCooldownReadyNotification(
                accountName: accountName,
                at: date
            )
        }
    }

    func cancelNotification(for accountName: String) {
        let identifier = "cooldown-\(accountName.replacingOccurrences(of: " ", with: "-"))"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

extension NotificationManager: NotificationScheduling {}

extension UNUserNotificationCenter: @unchecked Sendable {}
extension UNUserNotificationCenter: UserNotificationCentering {}
