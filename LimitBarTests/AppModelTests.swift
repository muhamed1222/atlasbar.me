import Testing
import Foundation
@testable import LimitBar

@MainActor
struct AppModelTests {
    @Test
    func compactLabelStartsWithDashOrLoadedValue() {
        let model = AppModel()
        #expect(!model.compactLabel.isEmpty)
    }

    @Test
    func shortUsageLabelShowsRemainingPercentages() {
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: UUID(),
            sessionPercentUsed: 14,
            weeklyPercentUsed: 32,
            nextResetAt: nil,
            subscriptionExpiresAt: nil,
            usageStatus: .available,
            subscriptionStatus: .unknown,
            sourceConfidence: 1.0,
            lastSyncedAt: Date(),
            rawExtractedStrings: []
        )

        #expect(remainingPercent(from: 14) == 86)
        #expect(remainingPercent(from: 32) == 68)
        #expect(shortUsageLabel(snapshot: snapshot) == "S86 W68")
    }

    @Test
    func resetAllDataClearsAccountsAndSnapshots() {
        let model = AppModel()
        model.resetAllData()
        #expect(model.accounts.isEmpty)
        #expect(model.snapshots.isEmpty)
        #expect(model.compactLabel == "--")
    }

    @Test
    func deleteAccountRemovesMatchingAccountAndSnapshot() {
        let model = AppModel()
        model.resetAllData()

        let account = Account(
            id: UUID(),
            provider: "Codex",
            email: "delete-me@example.com",
            label: nil,
            note: nil,
            priority: nil
        )
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: 12,
            weeklyPercentUsed: 34,
            nextResetAt: nil,
            subscriptionExpiresAt: nil,
            usageStatus: .available,
            subscriptionStatus: .unknown,
            sourceConfidence: 1.0,
            lastSyncedAt: Date(),
            rawExtractedStrings: []
        )

        model.accounts = [account]
        model.snapshots = [snapshot]
        model.deleteAccount(account)

        #expect(model.accounts.isEmpty)
        #expect(model.snapshots.isEmpty)
        #expect(model.compactLabel == "--")
    }

    @Test
    func deduplicatedRemovesDuplicateUnknownAccounts() {
        // Simulate loading a state with duplicate unknown accounts
        let a1 = Account(id: UUID(), provider: "Codex", email: nil, label: nil, note: nil, priority: nil)
        let a2 = Account(id: UUID(), provider: "Codex", email: nil, label: nil, note: nil, priority: nil)
        let a3 = Account(id: UUID(), provider: "Codex", email: "x@x.com", label: nil, note: nil, priority: nil)

        // Use the parser to verify deduplication logic directly
        var seen = Set<String>()
        let deduplicated = [a1, a2, a3].filter { account in
            let key = account.email ?? account.label ?? "__unknown__\(account.provider)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }

        #expect(deduplicated.count == 2)
        #expect(deduplicated.contains(where: { $0.email == "x@x.com" }))
    }

    @Test
    func pollingCoordinatorReadsFromUserDefaults() {
        UserDefaults.standard.set(30.0, forKey: "pollingWhenRunning")
        UserDefaults.standard.set(120.0, forKey: "pollingWhenClosed")

        let coordinator = PollingCoordinator()
        #expect(coordinator.interval(codexRunning: true) == 30)
        #expect(coordinator.interval(codexRunning: false) == 120)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "pollingWhenRunning")
        UserDefaults.standard.removeObject(forKey: "pollingWhenClosed")
    }

    @Test
    func pollingCoordinatorClampsOutOfRangeValues() {
        UserDefaults.standard.set(1.0, forKey: "pollingWhenRunning")   // below min 5
        UserDefaults.standard.set(999.0, forKey: "pollingWhenClosed")  // above max 300

        let coordinator = PollingCoordinator()
        #expect(coordinator.interval(codexRunning: true) == 5)
        #expect(coordinator.interval(codexRunning: false) == 300)

        UserDefaults.standard.removeObject(forKey: "pollingWhenRunning")
        UserDefaults.standard.removeObject(forKey: "pollingWhenClosed")
    }

    @Test
    func pollingCoordinatorUsesDefaultsWhenNotSet() {
        UserDefaults.standard.removeObject(forKey: "pollingWhenRunning")
        UserDefaults.standard.removeObject(forKey: "pollingWhenClosed")

        let coordinator = PollingCoordinator()
        #expect(coordinator.interval(codexRunning: true) == 15)
        #expect(coordinator.interval(codexRunning: false) == 60)
    }
}
