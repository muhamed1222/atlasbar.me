import Foundation
import Testing
@testable import LimitBar

struct DailyResetRecoveryCoordinatorTests {
    @Test
    func reconcileRecoversDueSnapshotImmediately() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let coordinator = DailyResetRecoveryCoordinator()
        let accountId = UUID()
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: accountId,
            sessionPercentUsed: 100,
            weeklyPercentUsed: 66,
            nextResetAt: now.addingTimeInterval(-60),
            weeklyResetAt: now.addingTimeInterval(4 * 24 * 60 * 60),
            subscriptionExpiresAt: now.addingTimeInterval(10 * 24 * 60 * 60),
            planType: "plus",
            usageStatus: .exhausted,
            stateOrigin: .server,
            sourceConfidence: 1,
            lastSyncedAt: now.addingTimeInterval(-300),
            rawExtractedStrings: [],
            totalTokensToday: nil,
            totalTokensThisWeek: nil
        )

        let outcome = coordinator.reconcile(
            snapshots: [snapshot],
            now: now
        )

        #expect(outcome.recoveredAccountIDs == [accountId])
        #expect(outcome.snapshots.first?.usageStatus == .available)
        #expect(outcome.snapshots.first?.sessionPercentUsed == 0)
        #expect(outcome.snapshots.first?.weeklyPercentUsed == 66)
        #expect(outcome.snapshots.first?.stateOrigin == .predictedReset)
        #expect(outcome.snapshots.first?.weeklyResetAt == snapshot.weeklyResetAt)
        #expect(outcome.snapshots.first?.subscriptionExpiresAt == snapshot.subscriptionExpiresAt)
        #expect(outcome.snapshots.first?.planType == snapshot.planType)
        #expect(outcome.snapshots.first?.lastSyncedAt == now)
        #expect(outcome.nextRecoveryAt == nil)
    }

    @Test
    func reconcileReturnsNextFutureResetForScheduler() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let coordinator = DailyResetRecoveryCoordinator()
        let soon = now.addingTimeInterval(300)
        let later = now.addingTimeInterval(900)

        let outcome = coordinator.reconcile(
            snapshots: [
                UsageSnapshot(
                    id: UUID(),
                    accountId: UUID(),
                    sessionPercentUsed: 100,
                    weeklyPercentUsed: 20,
                    nextResetAt: later,
                    weeklyResetAt: nil,
                    subscriptionExpiresAt: nil,
                    planType: nil,
                    usageStatus: .exhausted,
                    stateOrigin: .server,
                    sourceConfidence: 1,
                    lastSyncedAt: now,
                    rawExtractedStrings: [],
                    totalTokensToday: nil,
                    totalTokensThisWeek: nil
                ),
                UsageSnapshot(
                    id: UUID(),
                    accountId: UUID(),
                    sessionPercentUsed: 95,
                    weeklyPercentUsed: 20,
                    nextResetAt: soon,
                    weeklyResetAt: nil,
                    subscriptionExpiresAt: nil,
                    planType: nil,
                    usageStatus: .coolingDown,
                    stateOrigin: .server,
                    sourceConfidence: 1,
                    lastSyncedAt: now,
                    rawExtractedStrings: [],
                    totalTokensToday: nil,
                    totalTokensThisWeek: nil
                ),
                UsageSnapshot(
                    id: UUID(),
                    accountId: UUID(),
                    sessionPercentUsed: nil,
                    weeklyPercentUsed: 20,
                    nextResetAt: now.addingTimeInterval(1200),
                    weeklyResetAt: nil,
                    subscriptionExpiresAt: nil,
                    planType: nil,
                    usageStatus: .available,
                    stateOrigin: .server,
                    sourceConfidence: 1,
                    lastSyncedAt: now,
                    rawExtractedStrings: [],
                    totalTokensToday: nil,
                    totalTokensThisWeek: nil
                )
            ],
            now: now
        )

        #expect(outcome.nextRecoveryAt == soon)
        #expect(outcome.recoveredAccountIDs.isEmpty)
        #expect(outcome.snapshots[0].usageStatus == .exhausted)
        #expect(outcome.snapshots[1].usageStatus == .coolingDown)
        #expect(outcome.snapshots[2].usageStatus == .available)
        #expect(outcome.snapshots[0].nextResetAt == later)
        #expect(outcome.snapshots[1].nextResetAt == soon)
    }

    @Test
    func reconcileRecoversStaleSnapshotAtNowBoundary() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let coordinator = DailyResetRecoveryCoordinator()
        let accountId = UUID()
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: accountId,
            sessionPercentUsed: 82,
            weeklyPercentUsed: 37,
            nextResetAt: now,
            weeklyResetAt: now.addingTimeInterval(2 * 24 * 60 * 60),
            subscriptionExpiresAt: now.addingTimeInterval(6 * 24 * 60 * 60),
            planType: "pro",
            usageStatus: .stale,
            stateOrigin: .server,
            sourceConfidence: 1,
            lastSyncedAt: now.addingTimeInterval(-180),
            rawExtractedStrings: [],
            totalTokensToday: nil,
            totalTokensThisWeek: nil
        )

        let outcome = coordinator.reconcile(
            snapshots: [snapshot],
            now: now
        )

        #expect(outcome.recoveredAccountIDs == [accountId])
        #expect(outcome.snapshots[0].usageStatus == .available)
        #expect(outcome.snapshots[0].sessionPercentUsed == 0)
        #expect(outcome.snapshots[0].stateOrigin == .predictedReset)
        #expect(outcome.snapshots[0].weeklyPercentUsed == snapshot.weeklyPercentUsed)
        #expect(outcome.snapshots[0].nextResetAt == now)
        #expect(outcome.nextRecoveryAt == nil)
    }

    @Test
    func reconcileSchedulesFutureStaleSnapshotWithoutEarlyRecovery() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let coordinator = DailyResetRecoveryCoordinator()
        let futureReset = now.addingTimeInterval(60)
        let accountId = UUID()
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: accountId,
            sessionPercentUsed: 64,
            weeklyPercentUsed: 22,
            nextResetAt: futureReset,
            weeklyResetAt: nil,
            subscriptionExpiresAt: nil,
            planType: nil,
            usageStatus: .stale,
            stateOrigin: .server,
            sourceConfidence: 1,
            lastSyncedAt: now.addingTimeInterval(-300),
            rawExtractedStrings: [],
            totalTokensToday: nil,
            totalTokensThisWeek: nil
        )

        let outcome = coordinator.reconcile(
            snapshots: [snapshot],
            now: now
        )

        #expect(outcome.recoveredAccountIDs.isEmpty)
        #expect(outcome.snapshots[0].usageStatus == .stale)
        #expect(outcome.snapshots[0].sessionPercentUsed == 64)
        #expect(outcome.snapshots[0].stateOrigin == .server)
        #expect(outcome.nextRecoveryAt == futureReset)
    }

    @Test
    func reconcileKeepsWeeklyExhaustedSnapshotBlockedUntilWeeklyReset() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let coordinator = DailyResetRecoveryCoordinator()
        let sessionReset = now.addingTimeInterval(-60)
        let weeklyReset = now.addingTimeInterval(12 * 60 * 60)
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: UUID(),
            sessionPercentUsed: 100,
            weeklyPercentUsed: 100,
            nextResetAt: sessionReset,
            weeklyResetAt: weeklyReset,
            subscriptionExpiresAt: nil,
            planType: nil,
            usageStatus: .exhausted,
            stateOrigin: .server,
            sourceConfidence: 1,
            lastSyncedAt: now.addingTimeInterval(-300),
            rawExtractedStrings: [],
            totalTokensToday: nil,
            totalTokensThisWeek: nil
        )

        let outcome = coordinator.reconcile(
            snapshots: [snapshot],
            now: now
        )

        #expect(outcome.recoveredAccountIDs.isEmpty)
        #expect(outcome.snapshots[0].usageStatus == .exhausted)
        #expect(outcome.snapshots[0].sessionPercentUsed == 100)
        #expect(outcome.snapshots[0].weeklyPercentUsed == 100)
        #expect(outcome.nextRecoveryAt == weeklyReset)
    }

    @Test
    func reconcileRecoversWeeklyExhaustedSnapshotAtWeeklyBoundary() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let coordinator = DailyResetRecoveryCoordinator()
        let accountId = UUID()
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: accountId,
            sessionPercentUsed: 40,
            weeklyPercentUsed: 100,
            nextResetAt: now.addingTimeInterval(30 * 60),
            weeklyResetAt: now.addingTimeInterval(-60),
            subscriptionExpiresAt: nil,
            planType: nil,
            usageStatus: .exhausted,
            stateOrigin: .server,
            sourceConfidence: 1,
            lastSyncedAt: now.addingTimeInterval(-300),
            rawExtractedStrings: [],
            totalTokensToday: nil,
            totalTokensThisWeek: nil
        )

        let outcome = coordinator.reconcile(
            snapshots: [snapshot],
            now: now
        )

        #expect(outcome.recoveredAccountIDs == [accountId])
        #expect(outcome.snapshots[0].usageStatus == .available)
        #expect(outcome.snapshots[0].sessionPercentUsed == 0)
        #expect(outcome.snapshots[0].weeklyPercentUsed == 0)
        #expect(outcome.snapshots[0].stateOrigin == .predictedReset)
        #expect(outcome.nextRecoveryAt == nil)
    }
}
