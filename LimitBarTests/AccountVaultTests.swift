import Testing
import Foundation
@testable import LimitBar

// MARK: - Fake vault for AppModel injection

private final class SpyVault: AccountVaulting, @unchecked Sendable {
    private(set) var savedEmails: [String] = []
    private(set) var switchedToEmails: [String] = []
    var activeEmailValue: String?
    var savedEntries: Set<String> = []
    var switchError: Error? = nil

    func saveCurrentAuth(for email: String) throws {
        savedEmails.append(email)
        savedEntries.insert(email)
    }

    func hasSavedAuth(for email: String) -> Bool {
        savedEntries.contains(email)
    }

    func switchTo(email: String) throws {
        if let error = switchError { throw error }
        switchedToEmails.append(email)
        activeEmailValue = email
    }

    func activeEmail() -> String? {
        activeEmailValue
    }
}

@MainActor
private final class SpySessionSwitcher: CodexSessionSwitching {
    private(set) var switchedEmails: [String] = []
    var resultEmail: String?
    var switchError: Error?

    func switchTo(email: String) async throws -> String {
        switchedEmails.append(email)
        if let switchError { throw switchError }
        return resultEmail ?? email
    }
}

// MARK: - AppModel + vault tests

@MainActor
struct AccountVaultTests {

    @Test
    func storedAuthVaultNormalizesEmailKeys() {
        var vault = StoredAuthVault()
        let payload = Data("auth".utf8)

        vault.setAuthData(payload, for: " User@Example.com ")

        #expect(vault.authData(for: "user@example.com") == payload)
        #expect(vault.authData(for: "USER@example.com") == payload)
    }

    // MARK: canSwitch

    @Test
    func canSwitchReturnsFalseWhenAccountHasNoEmail() {
        let vault = SpyVault()
        let model = AppModel(vault: vault, shouldStartPolling: false)
        let account = Account(id: UUID(), provider: "Codex", email: nil, label: nil)
        #expect(model.canSwitch(to: account) == false)
    }

    @Test
    func canSwitchReturnsFalseForCurrentlyActiveAccount() {
        let vault = SpyVault()
        vault.activeEmailValue = "active@example.com"
        vault.savedEntries = ["active@example.com"]
        let model = AppModel(vault: vault, shouldStartPolling: false)
        model.activeCodexEmail = "active@example.com"
        let account = Account(id: UUID(), provider: "Codex", email: "active@example.com", label: nil)
        #expect(model.canSwitch(to: account) == false)
    }

    @Test
    func canSwitchReturnsFalseWhenNoVaultEntry() {
        let vault = SpyVault()
        vault.activeEmailValue = "other@example.com"
        let model = AppModel(vault: vault, shouldStartPolling: false)
        model.activeCodexEmail = "other@example.com"
        let account = Account(id: UUID(), provider: "Codex", email: "target@example.com", label: nil)
        #expect(model.canSwitch(to: account) == false)
    }

    @Test
    func canSwitchReturnsTrueForNonActiveAccountWithVaultEntry() {
        let vault = SpyVault()
        vault.activeEmailValue = "current@example.com"
        vault.savedEntries = ["target@example.com"]
        let model = AppModel(vault: vault, shouldStartPolling: false)
        model.activeCodexEmail = "current@example.com"
        let account = Account(id: UUID(), provider: "Codex", email: "target@example.com", label: nil)
        #expect(model.canSwitch(to: account) == true)
    }

    @Test
    func canSwitchReturnsFalseForNonCodexAccount() {
        let vault = SpyVault()
        vault.activeEmailValue = "current@example.com"
        vault.savedEntries = ["target@example.com"]
        let model = AppModel(vault: vault, shouldStartPolling: false)
        model.activeCodexEmail = "current@example.com"
        let account = Account(id: UUID(), provider: "Claude", email: "target@example.com", label: nil)
        #expect(model.canSwitch(to: account) == false)
    }

    // MARK: switchToAccount

    @Test
    func switchToAccountUpdatesActiveCodexEmail() async {
        let vault = SpyVault()
        vault.activeEmailValue = "new@example.com"
        let sessionSwitcher = SpySessionSwitcher()
        sessionSwitcher.resultEmail = "new@example.com"
        let model = AppModel(vault: vault, sessionSwitcher: sessionSwitcher, shouldStartPolling: false)
        model.activeCodexEmail = "current@example.com"

        let account = Account(id: UUID(), provider: "Codex", email: "new@example.com", label: nil)
        await model.switchToAccountAsync(account)

        #expect(model.activeCodexEmail == "new@example.com")
    }

    @Test
    func switchToAccountCallsSessionSwitcher() async {
        let vault = SpyVault()
        vault.activeEmailValue = "new@example.com"
        let sessionSwitcher = SpySessionSwitcher()
        let model = AppModel(vault: vault, sessionSwitcher: sessionSwitcher, shouldStartPolling: false)

        let account = Account(id: UUID(), provider: "Codex", email: "new@example.com", label: nil)
        await model.switchToAccountAsync(account)

        #expect(sessionSwitcher.switchedEmails == ["new@example.com"])
    }

    @Test
    func switchToAccountDoesNothingWhenEmailIsNil() async {
        let vault = SpyVault()
        let sessionSwitcher = SpySessionSwitcher()
        let model = AppModel(vault: vault, sessionSwitcher: sessionSwitcher, shouldStartPolling: false)

        let account = Account(id: UUID(), provider: "Codex", email: nil, label: nil)
        await model.switchToAccountAsync(account)

        #expect(sessionSwitcher.switchedEmails.isEmpty)
    }

    @Test
    func switchToAccountDoesNotUpdateEmailOnSwitchError() async {
        let vault = SpyVault()
        let sessionSwitcher = SpySessionSwitcher()
        sessionSwitcher.switchError = NSError(domain: "VaultTest", code: 1)
        let model = AppModel(vault: vault, sessionSwitcher: sessionSwitcher, shouldStartPolling: false)
        model.activeCodexEmail = "current@example.com"

        let account = Account(id: UUID(), provider: "Codex", email: "new@example.com", label: nil)
        await model.switchToAccountAsync(account)

        #expect(model.activeCodexEmail == "current@example.com")
        #expect(model.switchErrorMessage != nil)
    }

    // MARK: performRefresh + vault

    @Test
    func refreshSavesAuthToVaultWhenEmailIsAvailable() async {
        let vault = SpyVault()
        vault.activeEmailValue = "user@example.com"

        let payload = CurrentUsagePayload(
            accountIdentifier: "user@example.com",
            planType: nil,
            subscriptionExpiresAt: nil,
            sessionPercentUsed: 50,
            weeklyPercentUsed: 30,
            nextResetAt: nil,
            usageStatus: .available,
            sourceConfidence: 1.0,
            rawExtractedStrings: []
        )
        let model = AppModel(
            usageProvider: FakeCurrentUsageProvider(result: payload),
            runningChecker: FakeRunningChecker(isCodexRunning: false),
            vault: vault,
            shouldStartPolling: false
        )

        await model.refreshNowAsync()

        #expect(vault.savedEmails.contains("user@example.com"))
    }

    @Test
    func refreshUpdatesActiveCodexEmail() async {
        let vault = SpyVault()
        vault.activeEmailValue = "refreshed@example.com"

        let model = AppModel(
            usageProvider: FakeCurrentUsageProvider(result: nil),
            runningChecker: FakeRunningChecker(isCodexRunning: false),
            vault: vault,
            shouldStartPolling: false
        )

        await model.refreshNowAsync()

        #expect(model.activeCodexEmail == "refreshed@example.com")
    }

    @Test
    func refreshSetsActiveCodexEmailToNilWhenNoAuth() async {
        let vault = SpyVault()
        vault.activeEmailValue = nil

        let model = AppModel(
            usageProvider: FakeCurrentUsageProvider(result: nil),
            runningChecker: FakeRunningChecker(isCodexRunning: false),
            vault: vault,
            shouldStartPolling: false
        )
        model.activeCodexEmail = "stale@example.com"

        await model.refreshNowAsync()

        #expect(model.activeCodexEmail == nil)
    }
}

// MARK: - Stubs reused from AppModelTests

private struct FakeCurrentUsageProvider: CurrentUsageProviding {
    let result: CurrentUsagePayload?
    func fetchCurrentUsage() async -> CurrentUsagePayload? { result }
}

private struct FakeRunningChecker: CodexRunningChecking {
    let isCodexRunning: Bool
}
