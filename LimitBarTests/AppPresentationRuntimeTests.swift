import Testing
import Foundation
@testable import LimitBar

struct AppPresentationRuntimeTests {
    @Test
    func sortsAccountsByPriorityThenRecencyThenName() {
        let runtime = AppPresentationRuntime()
        let primary = Account(id: UUID(), provider: .codex, email: "b@example.com", label: nil)
        let backup = Account(id: UUID(), provider: .codex, email: "a@example.com", label: nil)
        let plain = Account(id: UUID(), provider: .codex, email: "c@example.com", label: nil)

        let sorted = runtime.sortAccounts(
            accounts: [plain, backup, primary],
            accountMetadata: [
                AccountMetadata(accountId: backup.id, priority: .backup),
                AccountMetadata(accountId: primary.id, priority: .primary)
            ],
            snapshots: [
                UsageSnapshot(
                    id: UUID(),
                    accountId: plain.id,
                    sessionPercentUsed: nil,
                    weeklyPercentUsed: nil,
                    nextResetAt: nil,
                    subscriptionExpiresAt: nil,
                    usageStatus: .unknown,
                    sourceConfidence: 0,
                    lastSyncedAt: Date(timeIntervalSince1970: 10),
                    rawExtractedStrings: []
                ),
                UsageSnapshot(
                    id: UUID(),
                    accountId: backup.id,
                    sessionPercentUsed: nil,
                    weeklyPercentUsed: nil,
                    nextResetAt: nil,
                    subscriptionExpiresAt: nil,
                    usageStatus: .unknown,
                    sourceConfidence: 0,
                    lastSyncedAt: Date(timeIntervalSince1970: 20),
                    rawExtractedStrings: []
                ),
                UsageSnapshot(
                    id: UUID(),
                    accountId: primary.id,
                    sessionPercentUsed: nil,
                    weeklyPercentUsed: nil,
                    nextResetAt: nil,
                    subscriptionExpiresAt: nil,
                    usageStatus: .unknown,
                    sourceConfidence: 0,
                    lastSyncedAt: Date(timeIntervalSince1970: 30),
                    rawExtractedStrings: []
                )
            ]
        )

        #expect(sorted.map(\.id) == [primary.id, backup.id, plain.id])
    }

    @Test
    func sortsExpiredSubscriptionsToBottom() {
        let runtime = AppPresentationRuntime()
        let now = Date(timeIntervalSince1970: 1_000_000)
        let expiredPrimary = Account(id: UUID(), provider: .codex, email: "expired@example.com", label: nil)
        let activeBackup = Account(id: UUID(), provider: .codex, email: "backup@example.com", label: nil)
        let activePlain = Account(id: UUID(), provider: .codex, email: "plain@example.com", label: nil)

        let sorted = runtime.sortAccounts(
            accounts: [expiredPrimary, activePlain, activeBackup],
            accountMetadata: [
                AccountMetadata(accountId: expiredPrimary.id, priority: .primary),
                AccountMetadata(accountId: activeBackup.id, priority: .backup)
            ],
            snapshots: [
                UsageSnapshot(
                    id: UUID(),
                    accountId: expiredPrimary.id,
                    sessionPercentUsed: nil,
                    weeklyPercentUsed: nil,
                    nextResetAt: nil,
                    subscriptionExpiresAt: now.addingTimeInterval(-60),
                    usageStatus: .unknown,
                    sourceConfidence: 0,
                    lastSyncedAt: now.addingTimeInterval(30),
                    rawExtractedStrings: []
                ),
                UsageSnapshot(
                    id: UUID(),
                    accountId: activeBackup.id,
                    sessionPercentUsed: nil,
                    weeklyPercentUsed: nil,
                    nextResetAt: nil,
                    subscriptionExpiresAt: now.addingTimeInterval(10 * 24 * 60 * 60),
                    usageStatus: .unknown,
                    sourceConfidence: 0,
                    lastSyncedAt: now.addingTimeInterval(20),
                    rawExtractedStrings: []
                ),
                UsageSnapshot(
                    id: UUID(),
                    accountId: activePlain.id,
                    sessionPercentUsed: nil,
                    weeklyPercentUsed: nil,
                    nextResetAt: nil,
                    subscriptionExpiresAt: now.addingTimeInterval(10 * 24 * 60 * 60),
                    usageStatus: .unknown,
                    sourceConfidence: 0,
                    lastSyncedAt: now.addingTimeInterval(10),
                    rawExtractedStrings: []
                )
            ],
            now: now
        )

        #expect(sorted.map(\.id) == [activeBackup.id, activePlain.id, expiredPrimary.id])
    }

    @Test
    func menuBarPresentationUsesCountdownWhenOnlyCooldownSnapshotsExist() {
        let runtime = AppPresentationRuntime()
        let account = Account(id: UUID(), provider: .codex, email: "cooldown@example.com", label: nil)
        let now = Date(timeIntervalSince1970: 1_000)
        let resetAt = now.addingTimeInterval(600)
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: 100,
            weeklyPercentUsed: 40,
            nextResetAt: resetAt,
            subscriptionExpiresAt: nil,
            usageStatus: .coolingDown,
            sourceConfidence: 1,
            lastSyncedAt: now,
            rawExtractedStrings: []
        )

        let result = runtime.makeMenuBarPresentation(
            accounts: [account],
            snapshots: [snapshot],
            language: .english,
            now: now
        )

        #expect(result.compactLabel == countdownString(until: resetAt, now: now, language: .english))
        #expect(result.menuBarState == .allCoolingDown(nextResetAt: resetAt))
    }

    @Test
    func menuBarPresentationUsesWeeklyCountdownWhenWeekIsExhausted() {
        let runtime = AppPresentationRuntime()
        let account = Account(id: UUID(), provider: .codex, email: "weekly@example.com", label: nil)
        let now = Date(timeIntervalSince1970: 1_000)
        let sessionResetAt = now.addingTimeInterval(600)
        let weeklyResetAt = now.addingTimeInterval(2 * 24 * 60 * 60)
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: 40,
            weeklyPercentUsed: 100,
            nextResetAt: sessionResetAt,
            weeklyResetAt: weeklyResetAt,
            subscriptionExpiresAt: nil,
            usageStatus: .exhausted,
            sourceConfidence: 1,
            lastSyncedAt: now,
            rawExtractedStrings: []
        )

        let result = runtime.makeMenuBarPresentation(
            accounts: [account],
            snapshots: [snapshot],
            language: .english,
            now: now
        )

        #expect(result.compactLabel == countdownString(until: weeklyResetAt, now: now, language: .english))
        #expect(result.menuBarState == .allCoolingDown(nextResetAt: weeklyResetAt))
    }

    @Test
    func menuBarPresentationAndSortingCanBeComputedSeparately() {
        let runtime = AppPresentationRuntime()
        let now = Date(timeIntervalSince1970: 2_000)
        let better = Account(id: UUID(), provider: .codex, email: "b@example.com", label: nil)
        let lower = Account(id: UUID(), provider: .codex, email: "a@example.com", label: nil)
        let snapshots = [
            UsageSnapshot(
                id: UUID(),
                accountId: lower.id,
                sessionPercentUsed: 80,
                weeklyPercentUsed: nil,
                nextResetAt: nil,
                subscriptionExpiresAt: nil,
                usageStatus: .available,
                sourceConfidence: 1,
                lastSyncedAt: now.addingTimeInterval(-60),
                rawExtractedStrings: []
            ),
            UsageSnapshot(
                id: UUID(),
                accountId: better.id,
                sessionPercentUsed: 10,
                weeklyPercentUsed: nil,
                nextResetAt: nil,
                subscriptionExpiresAt: nil,
                usageStatus: .available,
                sourceConfidence: 1,
                lastSyncedAt: now,
                rawExtractedStrings: []
            )
        ]
        let menuBarPresentation = runtime.makeMenuBarPresentation(
            accounts: [lower, better],
            snapshots: snapshots,
            language: .english,
            now: now
        )
        let sorted = runtime.sortAccounts(
            accounts: [lower, better],
            accountMetadata: [AccountMetadata(accountId: better.id, priority: .primary)],
            snapshots: snapshots,
            now: now
        )

        #expect(menuBarPresentation.compactLabel == "S90")
        #expect(menuBarPresentation.menuBarState == MenuBarState.available)
        #expect(sorted.map(\.id) == [better.id, lower.id])
    }
}
