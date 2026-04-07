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
    func fullProjectionIncludesMenuBarStateAndSortedAccounts() {
        let runtime = AppPresentationRuntime()
        let now = Date(timeIntervalSince1970: 2_000)
        let better = Account(id: UUID(), provider: .codex, email: "b@example.com", label: nil)
        let lower = Account(id: UUID(), provider: .codex, email: "a@example.com", label: nil)
        let projection = runtime.makeProjection(
            accounts: [lower, better],
            snapshots: [
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
            ],
            accountMetadata: [AccountMetadata(accountId: better.id, priority: .primary)],
            language: .english,
            now: now
        )

        #expect(projection.compactLabel == "S90")
        #expect(projection.menuBarState == .available)
        #expect(projection.sortedAccounts.map(\.id) == [better.id, lower.id])
    }
}
