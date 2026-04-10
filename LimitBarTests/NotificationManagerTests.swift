import Testing
import Foundation
import UserNotifications
@testable import LimitBar

private final class RecordingNotificationCenter: @unchecked Sendable, UserNotificationCentering {
    var authorizationGranted = true
    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var removedIdentifiers: [[String]] = []

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationGranted
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(identifiers)
    }
}

private final class BlockingAuthorizationNotificationCenter: @unchecked Sendable, UserNotificationCentering {
    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var removedIdentifiers: [[String]] = []
    private var continuation: CheckedContinuation<Bool, Error>?

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(identifiers)
    }

    func hasPendingAuthorizationRequest() -> Bool {
        continuation != nil
    }

    func resumeAuthorization(granted: Bool) {
        continuation?.resume(returning: granted)
        continuation = nil
    }
}

@Test
func cooldownNotificationBodyDoesNotExposeAccountIdentity() async throws {
    let center = RecordingNotificationCenter()
    let manager = NotificationManager(center: center)
    let accountId = UUID()

    manager.scheduleCooldownReadyNotification(
        accountId: accountId,
        at: Date().addingTimeInterval(60)
    )

    for _ in 0..<20 where center.addedRequests.isEmpty {
        try await Task.sleep(nanoseconds: 20_000_000)
    }

    #expect(center.addedRequests.count == 1)
    #expect(center.addedRequests[0].identifier == "cooldown-\(accountId.uuidString.lowercased())")
    #expect(center.addedRequests[0].content.title == "Account available again")
    #expect(center.addedRequests[0].content.body == "One of your tracked accounts should be ready to use.")
    #expect(center.addedRequests[0].content.body.contains("private@example.com") == false)
}

@Test
func renewalReminderBodyDoesNotExposeAccountIdentity() async throws {
    let center = RecordingNotificationCenter()
    let manager = NotificationManager(center: center)

    manager.scheduleRenewalReminder(
        identifier: "renewal-test",
        at: Date().addingTimeInterval(60)
    )

    for _ in 0..<20 where center.addedRequests.isEmpty {
        try await Task.sleep(nanoseconds: 20_000_000)
    }

    #expect(center.addedRequests.count == 1)
    #expect(center.addedRequests[0].identifier == "renewal-test")
    #expect(center.addedRequests[0].content.title == "Subscription renewal reminder")
    #expect(center.addedRequests[0].content.body == "One of your tracked accounts expires soon.")
    #expect(center.addedRequests[0].content.body.contains("private@example.com") == false)
}

@Test
func authorizationCanRecoverAfterInitialDenial() async {
    let center = RecordingNotificationCenter()
    let manager = NotificationManager(center: center)

    center.authorizationGranted = false
    #expect(await manager.requestAuthorization() == false)

    center.authorizationGranted = true
    #expect(await manager.requestAuthorization() == true)
}

@Test
func cancellingNotificationStopsInFlightSchedulingTask() async throws {
    let center = BlockingAuthorizationNotificationCenter()
    let manager = NotificationManager(center: center)
    let accountId = UUID()

    manager.scheduleCooldownReadyNotification(
        accountId: accountId,
        at: Date().addingTimeInterval(60)
    )

    for _ in 0..<20 where center.hasPendingAuthorizationRequest() == false {
        try await Task.sleep(nanoseconds: 20_000_000)
    }

    manager.cancelCooldownReadyNotification(accountId: accountId, accountName: "private@example.com")
    center.resumeAuthorization(granted: true)

    try await Task.sleep(nanoseconds: 100_000_000)

    #expect(center.addedRequests.isEmpty)
    #expect(
        center.removedIdentifiers.contains {
            $0.contains("cooldown-\(accountId.uuidString.lowercased())")
        }
    )
}
