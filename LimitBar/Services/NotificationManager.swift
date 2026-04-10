import Foundation
import UserNotifications

protocol UserNotificationCentering: AnyObject, Sendable {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

protocol NotificationScheduling: RenewalNotificationScheduling, AnyObject, Sendable {
    func requestAuthorization() async -> Bool
    func scheduleCooldownReadyNotification(accountId: UUID, at date: Date)
    func cancelCooldownReadyNotification(accountId: UUID, accountName: String)
}

private actor NotificationAuthorizationCoordinator {
    private enum State {
        case idle
        case requesting(Task<Bool, Never>)
        case authorized
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
        case .requesting(let task):
            return await task.value
        case .idle:
            let task = Task { [center] in
                (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            }
            state = .requesting(task)
            let granted = await task.value
            state = granted ? .authorized : .idle
            return granted
        }
    }
}

private final class PendingNotificationTaskCoordinator: @unchecked Sendable {
    private struct Entry {
        let token: UUID
        let task: Task<Void, Never>
    }

    private let lock = NSLock()
    private var entries: [String: Entry] = [:]

    func replaceTask(
        identifier: String,
        operation: @escaping @Sendable () async -> Void
    ) {
        cancelTasks(withIdentifiers: [identifier])

        let token = UUID()
        let task = Task { [weak self] in
            await operation()
            self?.finishTask(identifier: identifier, token: token)
        }

        lock.withLock {
            entries[identifier] = Entry(token: token, task: task)
        }
    }

    func cancelTasks(withIdentifiers identifiers: [String]) {
        let tasksToCancel = lock.withLock { () -> [Task<Void, Never>] in
            identifiers.compactMap { identifier in
                entries.removeValue(forKey: identifier)?.task
            }
        }

        for task in tasksToCancel {
            task.cancel()
        }
    }

    private func finishTask(identifier: String, token: UUID) {
        lock.withLock {
            guard entries[identifier]?.token == token else { return }
            entries.removeValue(forKey: identifier)
        }
    }
}

final class NotificationManager: @unchecked Sendable, NotificationScheduling {
    private let center: any UserNotificationCentering
    private let authorizationCoordinator: NotificationAuthorizationCoordinator
    private let taskCoordinator = PendingNotificationTaskCoordinator()

    init(center: any UserNotificationCentering = UNUserNotificationCenter.current()) {
        self.center = center
        self.authorizationCoordinator = NotificationAuthorizationCoordinator(center: center)
    }

    func requestAuthorization() async -> Bool {
        await authorizationCoordinator.requestAuthorization()
    }

    func scheduleCooldownReadyNotification(accountId: UUID, at date: Date) {
        let identifier = cooldownIdentifier(for: accountId)
        scheduleNotification(
            identifier: identifier,
            title: "Account available again",
            body: "One of your tracked accounts should be ready to use.",
            at: date
        )
    }

    func cancelCooldownReadyNotification(accountId: UUID, accountName: String) {
        taskCoordinator.cancelTasks(
            withIdentifiers: [
                cooldownIdentifier(for: accountId),
                legacyCooldownIdentifier(for: accountName)
            ]
        )
        center.removePendingNotificationRequests(
            withIdentifiers: [
                cooldownIdentifier(for: accountId),
                legacyCooldownIdentifier(for: accountName)
            ]
        )
    }

    func scheduleRenewalReminder(identifier: String, at date: Date) {
        scheduleNotification(
            identifier: identifier,
            title: "Subscription renewal reminder",
            body: "One of your tracked accounts expires soon.",
            at: date
        )
    }

    func cancelNotifications(withIdentifiers identifiers: [String]) {
        taskCoordinator.cancelTasks(withIdentifiers: identifiers)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func scheduleNotification(
        identifier: String,
        title: String,
        body: String,
        at date: Date
    ) {
        taskCoordinator.replaceTask(identifier: identifier) { [authorizationCoordinator, center] in
            guard !Task.isCancelled else { return }
            guard await authorizationCoordinator.requestAuthorization() else {
                return
            }
            guard !Task.isCancelled else { return }

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
            guard !Task.isCancelled else { return }
            try? await center.add(request)
        }
    }

    private func cooldownIdentifier(for accountId: UUID) -> String {
        "cooldown-\(accountId.uuidString.lowercased())"
    }

    private func legacyCooldownIdentifier(for accountName: String) -> String {
        "cooldown-\(accountName.replacingOccurrences(of: " ", with: "-"))"
    }
}

extension UNUserNotificationCenter: @retroactive @unchecked Sendable {}
extension UNUserNotificationCenter: UserNotificationCentering {}
