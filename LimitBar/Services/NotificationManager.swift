import Foundation
import UserNotifications

protocol UserNotificationCentering: AnyObject, Sendable {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

protocol NotificationScheduling: RenewalNotificationScheduling, AnyObject {
    func requestAuthorization() async -> Bool
    func scheduleCooldownReadyNotification(accountName: String, at date: Date)
    func cancelCooldownReadyNotification(accountName: String)
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
}

final class NotificationManager: NotificationScheduling {
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
        let identifier = cooldownIdentifier(for: accountName)
        scheduleNotification(
            identifier: identifier,
            title: "Account available again",
            body: "\(accountName) should be ready to use.",
            at: date
        )
    }

    func cancelCooldownReadyNotification(accountName: String) {
        center.removePendingNotificationRequests(withIdentifiers: [cooldownIdentifier(for: accountName)])
    }

    func scheduleRenewalReminder(identifier: String, accountName: String, at date: Date) {
        scheduleNotification(
            identifier: identifier,
            title: "Subscription renewal reminder",
            body: "\(accountName) expires soon.",
            at: date
        )
    }

    func cancelNotifications(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func scheduleNotification(
        identifier: String,
        title: String,
        body: String,
        at date: Date
    ) {
        Task { [authorizationCoordinator, center] in
            guard await authorizationCoordinator.requestAuthorization() else {
                return
            }

            let timeInterval = date.timeIntervalSinceNow
            guard timeInterval > 0 else { return }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: timeInterval,
                repeats: false
            )

            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    private func cooldownIdentifier(for accountName: String) -> String {
        "cooldown-\(accountName.replacingOccurrences(of: " ", with: "-"))"
    }
}

extension UNUserNotificationCenter: @unchecked Sendable {}
extension UNUserNotificationCenter: UserNotificationCentering {}
