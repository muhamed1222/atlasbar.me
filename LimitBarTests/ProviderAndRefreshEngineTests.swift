import Testing
import Foundation
@testable import LimitBar

private struct RefreshEngineFakeCoordinator: UsageRefreshing {
    let outcome: UsageRefreshOutcome

    func refresh(from state: PersistedState) async -> UsageRefreshOutcome {
        _ = state
        return outcome
    }
}

private final class RefreshEngineNotificationSpy: @unchecked Sendable, NotificationScheduling {
    func requestAuthorization() async -> Bool { true }
    func scheduleCooldownReadyNotification(accountId: UUID, at date: Date) {}
    func cancelCooldownReadyNotification(accountId: UUID, accountName: String) {}
    func scheduleRenewalReminder(identifier: String, at date: Date) {}
    func cancelNotifications(withIdentifiers identifiers: [String]) {}
}

struct ProviderAndRefreshEngineTests {
    @Test
    func accountDecodesLegacyProviderStringsCaseInsensitively() throws {
        let id = UUID()
        let json = """
        {
          "id": "\(id.uuidString)",
          "provider": "claude",
          "email": "claude@example.com"
        }
        """.data(using: .utf8)!

        let account = try JSONDecoder().decode(Account.self, from: json)

        #expect(account.provider == .claude)
    }

    @Test
    func refreshEngineBuildsPresentationStateFromRefreshOutcome() async {
        let account = Account(
            id: UUID(),
            provider: .codex,
            email: "codex@example.com",
            label: nil
        )
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: 18,
            weeklyPercentUsed: nil,
            nextResetAt: nil,
            weeklyResetAt: nil,
            subscriptionExpiresAt: nil,
            planType: "pro",
            usageStatus: .available,
            sourceConfidence: 1,
            lastSyncedAt: Date(timeIntervalSince1970: 100),
            rawExtractedStrings: []
        )
        let outcome = UsageRefreshOutcome(
            codexRunning: true,
            activeCodexEmail: account.email,
            activeClaudeAccountIdentifier: nil,
            accounts: [account],
            snapshots: [snapshot],
            persistenceErrorDetails: nil,
            shouldReconcileRenewalNotifications: false,
            shouldReconcileCooldownNotifications: false,
            claudeWebSessionStatus: nil
        )
        let engine = RefreshEngine(
            refreshCoordinator: RefreshEngineFakeCoordinator(outcome: outcome),
            notificationManager: RefreshEngineNotificationSpy()
        )

        let result = await engine.refresh(
            from: PersistedState(accounts: [], snapshots: []),
            language: .english
        )

        #expect(result.accounts == [account])
        #expect(result.snapshots == [snapshot])
        #expect(result.compactLabel == "S82")
        #expect(result.menuBarState == .available)
    }
}
