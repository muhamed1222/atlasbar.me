import Foundation
import Testing
@testable import LimitBar

private final class RenewalNotificationManagerSpy: @unchecked Sendable, RenewalNotificationScheduling {
    var scheduled: [RenewalReminderRequest] = []
    var cancelledIdentifiers: [String] = []

    func scheduleRenewalReminder(identifier: String, accountName: String, at date: Date) {
        scheduled.append(
            RenewalReminderRequest(
                identifier: identifier,
                fireDate: date,
                title: "Subscription renewal reminder",
                body: "\(accountName) expires soon."
            )
        )
    }

    func cancelNotifications(withIdentifiers identifiers: [String]) {
        cancelledIdentifiers.append(contentsOf: identifiers)
    }
}

struct RenewalReminderSchedulerTests {
    @Test
    func desiredRequestsReturnsAllEnabledFutureOffsets() {
        let scheduler = RenewalReminderScheduler()
        let now = Date(timeIntervalSince1970: 1_000_000)
        let expiry = now.addingTimeInterval(10 * 24 * 60 * 60)
        let account = Account(id: UUID(), provider: "Codex", email: "renew@example.com", label: nil)
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: nil,
            weeklyPercentUsed: nil,
            nextResetAt: nil,
            subscriptionExpiresAt: expiry,
            usageStatus: .available,
            sourceConfidence: 1,
            lastSyncedAt: now,
            rawExtractedStrings: []
        )

        let requests = scheduler.desiredRequests(
            account: account,
            snapshot: snapshot,
            settings: .default,
            now: now
        )

        #expect(requests.map(\.identifier) == [
            "renewal-\(account.id.uuidString)-7d",
            "renewal-\(account.id.uuidString)-3d",
            "renewal-\(account.id.uuidString)-1d",
            "renewal-\(account.id.uuidString)-0d"
        ])
    }

    @Test
    func desiredRequestsSkipsDisabledAndPastOffsets() {
        let scheduler = RenewalReminderScheduler()
        let now = Date(timeIntervalSince1970: 1_000_000)
        let expiry = now.addingTimeInterval(2 * 24 * 60 * 60)
        let account = Account(id: UUID(), provider: "Codex", email: "renew@example.com", label: nil)
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: nil,
            weeklyPercentUsed: nil,
            nextResetAt: nil,
            subscriptionExpiresAt: expiry,
            usageStatus: .available,
            sourceConfidence: 1,
            lastSyncedAt: now,
            rawExtractedStrings: []
        )

        let settings = AppSettingsState(
            pollingWhenRunning: nil,
            pollingWhenClosed: nil,
            cooldownNotificationsEnabled: true,
            renewalReminders: RenewalReminderSettings(
                days7Enabled: true,
                days3Enabled: false,
                days1Enabled: true,
                sameDayEnabled: true
            )
        )

        let requests = scheduler.desiredRequests(
            account: account,
            snapshot: snapshot,
            settings: settings,
            now: now
        )

        #expect(requests.map(\.identifier) == [
            "renewal-\(account.id.uuidString)-1d",
            "renewal-\(account.id.uuidString)-0d"
        ])
    }

    @Test
    func desiredRequestsSkipsExpiredAndUnknownSubscriptions() {
        let scheduler = RenewalReminderScheduler()
        let now = Date(timeIntervalSince1970: 1_000_000)
        let account = Account(id: UUID(), provider: "Codex", email: "renew@example.com", label: nil)

        let unknownSnapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: nil,
            weeklyPercentUsed: nil,
            nextResetAt: nil,
            subscriptionExpiresAt: nil,
            usageStatus: .available,
            sourceConfidence: 1,
            lastSyncedAt: now,
            rawExtractedStrings: []
        )
        let expiredSnapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: nil,
            weeklyPercentUsed: nil,
            nextResetAt: nil,
            subscriptionExpiresAt: now.addingTimeInterval(-60),
            usageStatus: .available,
            sourceConfidence: 1,
            lastSyncedAt: now,
            rawExtractedStrings: []
        )

        #expect(scheduler.desiredRequests(account: account, snapshot: unknownSnapshot, settings: .default, now: now).isEmpty)
        #expect(scheduler.desiredRequests(account: account, snapshot: expiredSnapshot, settings: .default, now: now).isEmpty)
    }

    @Test
    func reconcileCancelsAllKnownIdentifiersBeforeSchedulingDesiredOnes() {
        let scheduler = RenewalReminderScheduler()
        let now = Date(timeIntervalSince1970: 1_000_000)
        let expiry = now.addingTimeInterval(5 * 24 * 60 * 60)
        let account = Account(id: UUID(), provider: "Codex", email: "renew@example.com", label: nil)
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: nil,
            weeklyPercentUsed: nil,
            nextResetAt: nil,
            subscriptionExpiresAt: expiry,
            usageStatus: .available,
            sourceConfidence: 1,
            lastSyncedAt: now,
            rawExtractedStrings: []
        )
        let spy = RenewalNotificationManagerSpy()

        scheduler.reconcile(
            account: account,
            snapshot: snapshot,
            settings: .default,
            notificationManager: spy,
            now: now
        )

        #expect(Set(spy.cancelledIdentifiers) == Set(scheduler.reminderIdentifiers(for: account.id)))
        #expect(spy.scheduled.map(\.identifier) == [
            "renewal-\(account.id.uuidString)-3d",
            "renewal-\(account.id.uuidString)-1d",
            "renewal-\(account.id.uuidString)-0d"
        ])
    }
}
