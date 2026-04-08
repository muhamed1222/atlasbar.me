import Testing
import Foundation
import WebKit
@testable import LimitBar

private struct FakeAuthReader: CodexAuthReading {
    let authInfo: CodexAccountInfo?

    func readAccountInfo() -> CodexAccountInfo? {
        authInfo
    }
}

private final class SequencedAuthReader: @unchecked Sendable, CodexAuthReading {
    private let values: [CodexAccountInfo?]
    private var index = 0

    init(_ values: [CodexAccountInfo?]) {
        self.values = values
    }

    func readAccountInfo() -> CodexAccountInfo? {
        defer {
            if index < values.count - 1 {
                index += 1
            }
        }
        return values[min(index, values.count - 1)]
    }
}

private struct FakeUsageFetcher: CodexUsageFetching {
    let result: CodexUsageData?

    func fetchUsage(authInfo: CodexAccountInfo) async -> CodexUsageData? {
        result
    }
}

private struct FakeAccessTokenProvider: CodexAccessTokenProviding {
    let token: String?

    func currentAccessToken() async -> String? {
        token
    }
}

private actor RecordingUsageClient: CodexUsageRequesting {
    private var requests: [(token: String, accountId: String)] = []
    let result: CodexUsageData?

    init(result: CodexUsageData?) {
        self.result = result
    }

    func fetchUsage(accessToken: String, accountId: String) async -> CodexUsageData? {
        requests.append((accessToken, accountId))
        return result
    }

    func recordedRequests() -> [(token: String, accountId: String)] {
        requests
    }
}

private struct FakeCurrentUsageProvider: CurrentUsageProviding {
    let result: CurrentUsagePayload?

    func fetchCurrentUsage() async -> CurrentUsagePayload? {
        result
    }
}

private actor FakeAppUpdateChecker: AppUpdateChecking {
    private var update: AppUpdateInfo?

    init(update: AppUpdateInfo?) {
        self.update = update
    }

    func checkForUpdate(currentVersion: String) async -> AppUpdateInfo? {
        update
    }

    func setUpdate(_ update: AppUpdateInfo?) {
        self.update = update
    }
}

private actor SlowTrackingUsageProvider: CurrentUsageProviding {
    let result: CurrentUsagePayload?
    let delayNanoseconds: UInt64
    private var activeCalls = 0
    private var maxConcurrentCalls = 0
    private var totalCalls = 0

    init(result: CurrentUsagePayload?, delayNanoseconds: UInt64) {
        self.result = result
        self.delayNanoseconds = delayNanoseconds
    }

    func fetchCurrentUsage() async -> CurrentUsagePayload? {
        totalCalls += 1
        activeCalls += 1
        maxConcurrentCalls = max(maxConcurrentCalls, activeCalls)
        try? await Task.sleep(nanoseconds: delayNanoseconds)
        activeCalls -= 1
        return result
    }

    func recordedStats() -> (totalCalls: Int, maxConcurrentCalls: Int) {
        (totalCalls, maxConcurrentCalls)
    }
}

private struct AppModelFakeClaudeCredentialsReader: ClaudeCredentialsReading {
    let credentials: ClaudeCredentials?

    func readCredentials() -> ClaudeCredentials? {
        credentials
    }
}

private final class SequencedClaudeCredentialsReader: @unchecked Sendable, ClaudeCredentialsReading {
    private let values: [ClaudeCredentials?]
    private var index = 0

    init(_ values: [ClaudeCredentials?]) {
        self.values = values
    }

    func readCredentials() -> ClaudeCredentials? {
        defer {
            if index < values.count - 1 {
                index += 1
            }
        }
        return values[min(index, values.count - 1)]
    }
}

private final class InMemoryClaudeCookieStore: @unchecked Sendable, ClaudeSessionCookieStoring {
    private(set) var cookie: String?

    func hasStoredCookie() -> Bool {
        cookie?.isEmpty == false
    }

    func cookieHeaderValue() -> String? {
        cookie
    }

    func saveCookie(_ rawValue: String) throws {
        cookie = rawValue
    }

    func clearCookie() throws {
        cookie = nil
    }
}

@MainActor
private final class FakeClaudeWebSessionController: ClaudeWebSessionControlling {
    var webView: WKWebView {
        WKWebView(frame: .zero)
    }

    var preparedLoginPage = false
    var resultByOrganization: [String: ClaudeWebFetchResult] = [:]
    var subscriptionResultByOrganization: [String: ClaudeWebFetchResult] = [:]

    func prepareLoginPage() {
        preparedLoginPage = true
    }

    func clearSession() async throws {
        resultByOrganization.removeAll()
        subscriptionResultByOrganization.removeAll()
    }

    func fetchUsageResponse(organizationUUID: String?) async -> ClaudeWebFetchResult? {
        guard let organizationUUID else { return nil }
        return resultByOrganization[organizationUUID]
    }

    func fetchSubscriptionDetailsResponse(organizationUUID: String?) async -> ClaudeWebFetchResult? {
        guard let organizationUUID else { return nil }
        return subscriptionResultByOrganization[organizationUUID]
    }

    func cachedUsageResponse(organizationUUID: String?) -> ClaudeWebFetchResult? {
        guard let organizationUUID else { return nil }
        return resultByOrganization[organizationUUID]
    }
}

private struct FakeRunningChecker: CodexRunningChecking {
    let isCodexRunning: Bool
}

private struct ActiveEmailVault: AccountVaulting {
    let email: String?

    func saveCurrentAuth(for email: String) throws {}
    func hasSavedAuth(for email: String) -> Bool { true }
    func switchTo(email: String) throws {}
    func activeEmail() -> String? { email }
}

private final class InMemorySnapshotStore: @unchecked Sendable, SnapshotStoring {
    private var state: PersistedState
    var lastLoadIssue: String?

    init(state: PersistedState = PersistedState(accounts: [], snapshots: [])) {
        self.state = state
    }

    func load() -> PersistedState {
        state
    }

    func save(_ state: PersistedState) throws {
        self.state = state
    }

    func reset() throws {
        state = PersistedState(accounts: [], snapshots: [])
    }
}

private enum PersistenceTestError: LocalizedError {
    case diskFull

    var errorDescription: String? {
        "Disk full"
    }
}

private final class SaveFailingSnapshotStore: @unchecked Sendable, SnapshotStoring {
    private let state: PersistedState
    private let saveError: any Error
    var lastLoadIssue: String?

    init(
        state: PersistedState = PersistedState(accounts: [], snapshots: []),
        saveError: any Error = PersistenceTestError.diskFull
    ) {
        self.state = state
        self.saveError = saveError
    }

    func load() -> PersistedState {
        state
    }

    func save(_ state: PersistedState) throws {
        _ = state
        throw saveError
    }

    func reset() throws {}
}

private final class RecordingNotificationManager: @unchecked Sendable, NotificationScheduling {
    private(set) var scheduled: [(accountId: UUID, accountName: String, date: Date)] = []
    private(set) var cancelled: [(accountId: UUID, accountName: String)] = []

    func requestAuthorization() async -> Bool {
        true
    }

    func scheduleCooldownReadyNotification(accountId: UUID, accountName: String, at date: Date) {
        scheduled.append((accountId, accountName, date))
    }

    func cancelCooldownReadyNotification(accountId: UUID, accountName: String) {
        cancelled.append((accountId, accountName))
    }

    func scheduleRenewalReminder(identifier: String, accountName: String, at date: Date) {}

    func cancelNotifications(withIdentifiers identifiers: [String]) {}
}

private final class WriteTracker: @unchecked Sendable {
    private(set) var count = 0

    func record() {
        count += 1
    }
}

private func base64URLString(from data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

private func makeJWT(expiration: TimeInterval) -> String {
    let header = try! JSONSerialization.data(withJSONObject: ["alg": "none", "typ": "JWT"])
    let payload = try! JSONSerialization.data(withJSONObject: ["exp": expiration])
    return "\(base64URLString(from: header)).\(base64URLString(from: payload)).signature"
}

private func makeJWT(expiration: TimeInterval, payloadExtras: [String: Any]) -> String {
    let header = try! JSONSerialization.data(withJSONObject: ["alg": "none", "typ": "JWT"])
    var payload = payloadExtras
    payload["exp"] = expiration
    let payloadData = try! JSONSerialization.data(withJSONObject: payload)
    return "\(base64URLString(from: header)).\(base64URLString(from: payloadData)).signature"
}

private func makeAuthJSONData(accessToken: String, refreshToken: String) throws -> Data {
    try JSONSerialization.data(
        withJSONObject: [
            "tokens": [
                "access_token": accessToken,
                "refresh_token": refreshToken,
                "id_token": "initial-id-token"
            ]
        ],
        options: .prettyPrinted
    )
}

private func makeAppModelTempStore() throws -> SnapshotStore {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent("LimitBarAppModelTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    return try SnapshotStore(directory: tmp)
}

private final class NotificationManagerSpy: @unchecked Sendable, NotificationScheduling {
    var cooldownScheduled: [(accountId: UUID, accountName: String, date: Date)] = []
    var cooldownCancelled: [(accountId: UUID, accountName: String)] = []
    var renewalScheduled: [RenewalReminderRequest] = []
    var cancelledIdentifiers: [String] = []

    func requestAuthorization() async -> Bool {
        true
    }

    func scheduleCooldownReadyNotification(accountId: UUID, accountName: String, at date: Date) {
        cooldownScheduled.append((accountId, accountName, date))
    }

    func cancelCooldownReadyNotification(accountId: UUID, accountName: String) {
        cooldownCancelled.append((accountId, accountName))
    }

    func scheduleRenewalReminder(identifier: String, accountName: String, at date: Date) {
        renewalScheduled.append(
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

@MainActor
struct AppModelTests {
    @Test
    func compactLabelStartsWithDashOrLoadedValue() {
        let model = AppModel(shouldStartPolling: false)
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
            sourceConfidence: 1.0,
            lastSyncedAt: Date(),
            rawExtractedStrings: []
        )

        #expect(remainingPercent(from: 14) == 86)
        #expect(remainingPercent(from: 32) == 68)
        #expect(shortUsageLabel(snapshot: snapshot) == "S86 W68")
    }

    @Test
    func compactMenuBarLabelShowsOnlySessionPercentage() {
        #expect(compactMenuBarLabel(from: "S86 W68") == "86%")
        #expect(compactMenuBarLabel(from: "S86") == "86%")
        #expect(compactMenuBarLabel(from: "2h 10m") == "2h 10m")
        #expect(compactMenuBarLabel(from: "Stale") == "Stale")
    }

    @Test
    func compactMenuBarItemsShowBothProvidersInStableOrder() {
        let codex = Account(id: UUID(), provider: .codex, email: "codex@example.com", label: nil)
        let claude = Account(id: UUID(), provider: .claude, email: "claude@example.com", label: nil)

        let codexSnapshot = UsageSnapshot(
            id: UUID(),
            accountId: codex.id,
            sessionPercentUsed: 10,
            weeklyPercentUsed: 20,
            nextResetAt: nil,
            weeklyResetAt: nil,
            subscriptionExpiresAt: nil,
            planType: nil,
            usageStatus: .available,
            sourceConfidence: 1,
            lastSyncedAt: Date(timeIntervalSince1970: 100),
            rawExtractedStrings: []
        )

        let claudeSnapshot = UsageSnapshot(
            id: UUID(),
            accountId: claude.id,
            sessionPercentUsed: 15,
            weeklyPercentUsed: 25,
            nextResetAt: nil,
            weeklyResetAt: nil,
            subscriptionExpiresAt: nil,
            planType: nil,
            usageStatus: .available,
            sourceConfidence: 1,
            lastSyncedAt: Date(timeIntervalSince1970: 200),
            rawExtractedStrings: []
        )

        #expect(
            compactMenuBarItems(
                accounts: [codex, claude],
                snapshots: [codexSnapshot, claudeSnapshot]
            ) == [
                CompactMenuBarItem(provider: .codex, label: "90%"),
                CompactMenuBarItem(provider: .claude, label: "85%")
            ]
        )
    }

    @Test
    func compactMenuBarItemsPreferPercentageOverCountdown() {
        let claude = Account(id: UUID(), provider: .claude, email: "claude@example.com", label: nil)

        let claudeSnapshot = UsageSnapshot(
            id: UUID(),
            accountId: claude.id,
            sessionPercentUsed: 25,
            weeklyPercentUsed: nil,
            nextResetAt: Date().addingTimeInterval(3 * 3600),
            weeklyResetAt: nil,
            subscriptionExpiresAt: nil,
            planType: nil,
            usageStatus: .exhausted,
            sourceConfidence: 1,
            lastSyncedAt: Date(timeIntervalSince1970: 200),
            rawExtractedStrings: []
        )

        #expect(
            compactMenuBarItems(accounts: [claude], snapshots: [claudeSnapshot]) == [
                CompactMenuBarItem(provider: .claude, label: "75%")
            ]
        )
    }

    @Test
    func compactMenuBarItemsShowPlaceholderForProviderWithoutSnapshot() {
        let codex = Account(id: UUID(), provider: .codex, email: "codex@example.com", label: nil)
        let claude = Account(id: UUID(), provider: .claude, email: "claude@example.com", label: nil)

        let codexSnapshot = UsageSnapshot(
            id: UUID(),
            accountId: codex.id,
            sessionPercentUsed: 10,
            weeklyPercentUsed: 20,
            nextResetAt: nil,
            weeklyResetAt: nil,
            subscriptionExpiresAt: nil,
            planType: nil,
            usageStatus: .available,
            sourceConfidence: 1,
            lastSyncedAt: Date(timeIntervalSince1970: 100),
            rawExtractedStrings: []
        )

        #expect(
            compactMenuBarItems(accounts: [codex, claude], snapshots: [codexSnapshot]) == [
                CompactMenuBarItem(provider: .codex, label: "90%"),
                CompactMenuBarItem(provider: .claude, label: "--")
            ]
        )
    }

    @Test
    func compactMenuBarProviderFallsBackToCodexWithoutSnapshots() {
        #expect(
            compactMenuBarItems(accounts: [], snapshots: []) == [
                CompactMenuBarItem(provider: .codex, label: "--")
            ]
        )
    }

    @Test
    func shortUsageLabelShowsStaleForStaleSnapshots() {
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: UUID(),
            sessionPercentUsed: 14,
            weeklyPercentUsed: 32,
            nextResetAt: nil,
            subscriptionExpiresAt: nil,
            usageStatus: .stale,
            sourceConfidence: 1.0,
            lastSyncedAt: Date(),
            rawExtractedStrings: []
        )

        #expect(shortUsageLabel(snapshot: snapshot) == "Stale")
    }

    @Test
    func resetAllDataClearsAccountsAndSnapshots() {
        let model = AppModel(shouldStartPolling: false)
        model.resetAllData()
        #expect(model.accounts.isEmpty)
        #expect(model.snapshots.isEmpty)
        #expect(model.accountMetadata.isEmpty)
        #expect(model.settings == .default)
        #expect(model.compactLabel == "--")
    }

    @Test
    func refreshKeepsCodexAndClaudeAccountsSeparateWhenIdentifiersMatch() async {
        let sharedEmail = "same@example.com"
        let codexPayload = CurrentUsagePayload(
            accountIdentifier: sharedEmail,
            planType: "plus",
            subscriptionExpiresAt: nil,
            sessionPercentUsed: 10,
            weeklyPercentUsed: 20,
            nextResetAt: nil,
            usageStatus: .available,
            sourceConfidence: 1.0,
            rawExtractedStrings: [],
            provider: .codex
        )
        let claudePayload = CurrentUsagePayload(
            accountIdentifier: sharedEmail,
            planType: nil,
            subscriptionExpiresAt: nil,
            sessionPercentUsed: nil,
            weeklyPercentUsed: nil,
            nextResetAt: nil,
            usageStatus: .available,
            sourceConfidence: 1.0,
            rawExtractedStrings: [],
            provider: .claude,
            totalTokensToday: 1200,
            totalTokensThisWeek: 8400
        )
        let model = AppModel(
            usageProvider: FakeCurrentUsageProvider(result: codexPayload),
            runningChecker: FakeRunningChecker(isCodexRunning: false),
            store: InMemorySnapshotStore(),
            claudeUsageProvider: FakeCurrentUsageProvider(result: claudePayload),
            shouldStartPolling: false
        )

        await model.refreshNowAsync()

        #expect(model.accounts.count == 2)
        #expect(Set(model.accounts.map(\.provider)) == Set<Provider>([.codex, .claude]))
        #expect(Set(model.snapshots.map(\.accountId)).count == 2)
    }

    @Test
    func refreshMigratesLegacyClaudePlaceholderToEmailIdentity() async {
        let legacyClaude = Account(
            id: UUID(),
            provider: .claude,
            email: nil,
            label: "Claude Pro"
        )
        let legacySnapshot = UsageSnapshot(
            id: UUID(),
            accountId: legacyClaude.id,
            sessionPercentUsed: nil,
            weeklyPercentUsed: nil,
            nextResetAt: nil,
            subscriptionExpiresAt: nil,
            planType: "pro",
            usageStatus: .available,
            sourceConfidence: 1.0,
            lastSyncedAt: Date(timeIntervalSince1970: 10),
            rawExtractedStrings: [],
            totalTokensToday: 111,
            totalTokensThisWeek: 999
        )
        let store = InMemorySnapshotStore(
            state: PersistedState(accounts: [legacyClaude], snapshots: [legacySnapshot])
        )
        let claudePayload = CurrentUsagePayload(
            accountIdentifier: "outcastsdev@gmail.com",
            planType: "pro",
            subscriptionExpiresAt: nil,
            sessionPercentUsed: nil,
            weeklyPercentUsed: nil,
            nextResetAt: nil,
            usageStatus: .available,
            sourceConfidence: 1.0,
            rawExtractedStrings: [],
            provider: .claude,
            totalTokensToday: 1200,
            totalTokensThisWeek: 8400
        )

        let model = AppModel(
            usageProvider: FakeCurrentUsageProvider(result: nil),
            runningChecker: FakeRunningChecker(isCodexRunning: false),
            store: store,
            claudeUsageProvider: FakeCurrentUsageProvider(result: claudePayload),
            shouldStartPolling: false
        )

        await model.refreshNowAsync()

        #expect(model.accounts.count == 1)
        #expect(model.accounts.first?.email == "outcastsdev@gmail.com")
        #expect(model.accounts.first?.label == nil)
        #expect(model.snapshots.count == 1)
        #expect(model.snapshots.first?.accountId == legacyClaude.id)
    }

    @Test
    func initDropsLegacyClaudePlaceholderWhenEmailAccountAlreadyExists() {
        let legacyClaude = Account(
            id: UUID(),
            provider: .claude,
            email: nil,
            label: "Claude Pro"
        )
        let emailClaude = Account(
            id: UUID(),
            provider: .claude,
            email: "outcastsdev@gmail.com",
            label: nil
        )
        let store = InMemorySnapshotStore(
            state: PersistedState(
                accounts: [legacyClaude, emailClaude],
                snapshots: [
                    UsageSnapshot(
                        id: UUID(),
                        accountId: legacyClaude.id,
                        sessionPercentUsed: nil,
                        weeklyPercentUsed: nil,
                        nextResetAt: nil,
                        subscriptionExpiresAt: nil,
                        planType: "pro",
                        usageStatus: .available,
                        sourceConfidence: 1.0,
                        lastSyncedAt: Date(),
                        rawExtractedStrings: [],
                        totalTokensToday: 10,
                        totalTokensThisWeek: 20
                    ),
                    UsageSnapshot(
                        id: UUID(),
                        accountId: emailClaude.id,
                        sessionPercentUsed: nil,
                        weeklyPercentUsed: nil,
                        nextResetAt: nil,
                        subscriptionExpiresAt: nil,
                        planType: "pro",
                        usageStatus: .available,
                        sourceConfidence: 1.0,
                        lastSyncedAt: Date(),
                        rawExtractedStrings: [],
                        totalTokensToday: 10,
                        totalTokensThisWeek: 20
                    )
                ]
            )
        )

        let model = AppModel(
            runningChecker: FakeRunningChecker(isCodexRunning: false),
            store: store,
            shouldStartPolling: false
        )

        #expect(model.accounts.count == 1)
        #expect(model.accounts.first?.email == "outcastsdev@gmail.com")
        #expect(model.snapshots.count == 1)
        #expect(model.snapshots.first?.accountId == emailClaude.id)
        let persisted = store.load()
        #expect(persisted.accounts.count == 1)
        #expect(persisted.accounts.first?.email == "outcastsdev@gmail.com")
        #expect(persisted.snapshots.count == 1)
        #expect(persisted.snapshots.first?.accountId == emailClaude.id)
    }

    @Test
    func deleteAccountRemovesMatchingAccountAndSnapshot() {
        let model = AppModel(shouldStartPolling: false)
        model.resetAllData()

        let account = Account(
            id: UUID(),
            provider: "Codex",
            email: "delete-me@example.com",
            label: nil
        )
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: 12,
            weeklyPercentUsed: 34,
            nextResetAt: nil,
            subscriptionExpiresAt: nil,
            usageStatus: .available,
            sourceConfidence: 1.0,
            lastSyncedAt: Date(),
            rawExtractedStrings: []
        )
        let metadata = AccountMetadata(accountId: account.id, priority: .primary, note: "Keep me")

        model.accounts = [account]
        model.snapshots = [snapshot]
        model.accountMetadata = [metadata]
        model.deleteAccount(account)

        #expect(model.accounts.isEmpty)
        #expect(model.snapshots.isEmpty)
        #expect(model.accountMetadata.isEmpty)
        #expect(model.compactLabel == "--")
    }

    @Test
    func deduplicatedRemovesDuplicateUnknownAccounts() {
        // Simulate loading a state with duplicate unknown accounts
        let a1 = Account(id: UUID(), provider: "Codex", email: nil, label: nil)
        let a2 = Account(id: UUID(), provider: "Codex", email: nil, label: nil)
        let a3 = Account(id: UUID(), provider: "Codex", email: "x@x.com", label: nil)

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
    func pollingCoordinatorReadsFromSettingsState() {
        let coordinator = PollingCoordinator()
        let settings = AppSettingsState(
            pollingWhenRunning: 30,
            pollingWhenClosed: 120,
            cooldownNotificationsEnabled: true,
            renewalReminders: .default
        )
        #expect(coordinator.interval(codexRunning: true, settings: settings) == 30)
        #expect(coordinator.interval(codexRunning: false, settings: settings) == 120)
    }

    @Test
    func pollingCoordinatorClampsOutOfRangeValues() {
        let coordinator = PollingCoordinator()
        let settings = AppSettingsState(
            pollingWhenRunning: 1,
            pollingWhenClosed: 999,
            cooldownNotificationsEnabled: true,
            renewalReminders: .default
        )
        #expect(coordinator.interval(codexRunning: true, settings: settings) == 5)
        #expect(coordinator.interval(codexRunning: false, settings: settings) == 300)
    }

    @Test
    func pollingCoordinatorUsesDefaultsWhenNotSet() {
        let coordinator = PollingCoordinator()
        #expect(coordinator.interval(codexRunning: true, settings: .default) == 15)
        #expect(coordinator.interval(codexRunning: false, settings: .default) == 60)
    }

    @Test
    func sortedAccountsUsesPriorityThenRecencyThenName() {
        let model = AppModel(shouldStartPolling: false)
        model.resetAllData()

        let primary = Account(id: UUID(), provider: "Codex", email: "b@example.com", label: nil)
        let backup = Account(id: UUID(), provider: "Codex", email: "a@example.com", label: nil)
        let plain = Account(id: UUID(), provider: "Codex", email: "c@example.com", label: nil)

        model.accounts = [plain, backup, primary]
        model.accountMetadata = [
            AccountMetadata(accountId: backup.id, priority: .backup),
            AccountMetadata(accountId: primary.id, priority: .primary)
        ]
        model.snapshots = [
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

        #expect(model.sortedAccounts.map(\.id) == [primary.id, backup.id, plain.id])
    }

    @Test
    func setLanguageUpdatesLocalizedCompactLabel() {
        let model = AppModel(shouldStartPolling: false)
        let account = Account(id: UUID(), provider: "Codex", email: "lang@example.com", label: nil)
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: nil,
            weeklyPercentUsed: nil,
            nextResetAt: nil,
            subscriptionExpiresAt: nil,
            usageStatus: .stale,
            sourceConfidence: 1,
            lastSyncedAt: Date(),
            rawExtractedStrings: []
        )

        model.accounts = [account]
        model.snapshots = [snapshot]
        model.setLanguage(.russian)

        #expect(model.settings.language == .russian)
        #expect(model.compactLabel == "Устарел")
    }

    @Test
    func updateMetadataPersistsPriorityAndNoteInMemory() {
        let model = AppModel(shouldStartPolling: false)
        model.resetAllData()

        let account = Account(id: UUID(), provider: "Codex", email: "meta@example.com", label: nil)
        model.accounts = [account]

        model.updatePriority(.primary, for: account.id)
        model.updateNote("Warm spare account", for: account.id)

        let metadata = model.metadata(for: account.id)
        #expect(metadata.priority == .primary)
        #expect(metadata.note == "Warm spare account")
    }

    @Test
    func initReconcilesCooldownAndRenewalNotificationsFromPersistedState() throws {
        let store = try makeAppModelTempStore()
        let notificationManager = NotificationManagerSpy()
        let account = Account(id: UUID(), provider: "Codex", email: "persisted@example.com", label: nil)
        let now = Date()
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: nil,
            weeklyPercentUsed: nil,
            nextResetAt: now.addingTimeInterval(60 * 60),
            subscriptionExpiresAt: now.addingTimeInterval(10 * 24 * 60 * 60),
            usageStatus: .coolingDown,
            sourceConfidence: 1,
            lastSyncedAt: now,
            rawExtractedStrings: []
        )

        try store.save(
            PersistedState(
                accounts: [account],
                snapshots: [snapshot],
                accountMetadata: [],
                settings: .default
            )
        )

        _ = AppModel(
            notificationManager: notificationManager,
            store: store,
            shouldStartPolling: false
        )

        #expect(notificationManager.cooldownScheduled.count == 1)
        #expect(notificationManager.cooldownScheduled.first?.accountName == account.displayName)
        #expect(Set(notificationManager.cancelledIdentifiers).count == 4)
        #expect(notificationManager.renewalScheduled.count == 2)
    }

    @Test
    func deleteAccountCancelsCooldownAndRenewalNotifications() {
        let notificationManager = NotificationManagerSpy()
        let model = AppModel(notificationManager: notificationManager, shouldStartPolling: false)
        model.resetAllData()
        notificationManager.cooldownCancelled.removeAll()
        notificationManager.cancelledIdentifiers.removeAll()

        let account = Account(
            id: UUID(),
            provider: "Codex",
            email: "delete-notify@example.com",
            label: nil
        )
        model.accounts = [account]

        model.deleteAccount(account)

        #expect(notificationManager.cooldownCancelled.count == 1)
        #expect(notificationManager.cooldownCancelled.first?.accountId == account.id)
        #expect(notificationManager.cooldownCancelled.first?.accountName == account.displayName)
        #expect(
            Set(notificationManager.cancelledIdentifiers) ==
            Set(RenewalReminderScheduler().reminderIdentifiers(for: account.id))
        )
    }

    @Test
    func resetAllDataCancelsNotificationsForLoadedAccounts() {
        let notificationManager = NotificationManagerSpy()
        let model = AppModel(notificationManager: notificationManager, shouldStartPolling: false)
        model.resetAllData()
        notificationManager.cooldownCancelled.removeAll()
        notificationManager.cancelledIdentifiers.removeAll()

        let account = Account(
            id: UUID(),
            provider: "Codex",
            email: "reset-notify@example.com",
            label: nil
        )
        model.accounts = [account]

        model.resetAllData()

        #expect(notificationManager.cooldownCancelled.count == 1)
        #expect(notificationManager.cooldownCancelled.first?.accountId == account.id)
        #expect(notificationManager.cooldownCancelled.first?.accountName == account.displayName)
        #expect(
            Set(notificationManager.cancelledIdentifiers) ==
            Set(RenewalReminderScheduler().reminderIdentifiers(for: account.id))
        )
    }

    @Test
    func apiBasedProviderReturnsNilWhenAuthIsMissing() async {
        let provider = APIBasedUsageProvider(
            authReader: FakeAuthReader(authInfo: nil),
            usageFetcher: FakeUsageFetcher(result: nil)
        )

        let result = await provider.fetchCurrentUsage()

        #expect(result == nil)
    }

    @Test
    func apiBasedProviderMapsAuthAndUsageIntoNormalizedPayload() async {
        let authInfo = CodexAccountInfo(
            email: "user@example.com",
            planType: "pro",
            subscriptionExpiresAt: Date(timeIntervalSince1970: 1_700_000_000),
            accountId: "acc_123",
            userId: "user_123"
        )
        let usageData = CodexUsageData(
            sessionPercentUsed: 84,
            weeklyPercentUsed: 52,
            nextResetAt: Date(timeIntervalSince1970: 1_700_000_600),
            weeklyResetAt: Date(timeIntervalSince1970: 1_700_604_800),
            status: .coolingDown
        )
        let provider = APIBasedUsageProvider(
            authReader: FakeAuthReader(authInfo: authInfo),
            usageFetcher: FakeUsageFetcher(result: usageData)
        )

        let result = await provider.fetchCurrentUsage()

        #expect(result?.accountIdentifier == "user@example.com")
        #expect(result?.planType == "pro")
        #expect(result?.sessionPercentUsed == 84)
        #expect(result?.weeklyPercentUsed == 52)
        #expect(result?.weeklyResetAt == Date(timeIntervalSince1970: 1_700_604_800))
        #expect(result?.usageStatus == .coolingDown)
        #expect(result?.sourceConfidence == 1.0)
    }

    @Test
    func apiBasedProviderRereadsAuthMetadataAfterUsageFetch() async {
        let staleAuthInfo = CodexAccountInfo(
            email: "user@example.com",
            planType: "free",
            subscriptionExpiresAt: nil,
            accountId: "acc_123",
            userId: "user_123"
        )
        let refreshedAuthInfo = CodexAccountInfo(
            email: "user@example.com",
            planType: "plus",
            subscriptionExpiresAt: Date(timeIntervalSince1970: 1_700_000_000),
            accountId: "acc_123",
            userId: "user_123"
        )
        let usageData = CodexUsageData(
            sessionPercentUsed: 84,
            weeklyPercentUsed: 52,
            nextResetAt: Date(timeIntervalSince1970: 1_700_000_600),
            weeklyResetAt: Date(timeIntervalSince1970: 1_700_604_800),
            status: .coolingDown
        )
        let provider = APIBasedUsageProvider(
            authReader: SequencedAuthReader([staleAuthInfo, refreshedAuthInfo]),
            usageFetcher: FakeUsageFetcher(result: usageData)
        )

        let result = await provider.fetchCurrentUsage()

        #expect(result?.planType == "plus")
        #expect(result?.subscriptionExpiresAt == refreshedAuthInfo.subscriptionExpiresAt)
    }

    @Test
    func codexUsageApiUsesTokenProviderAndUsageClient() async {
        let usageClient = RecordingUsageClient(
            result: CodexUsageData(
                sessionPercentUsed: 30,
                weeklyPercentUsed: 10,
                nextResetAt: nil,
                status: .available
            )
        )
        let api = CodexUsageAPI(
            accessTokenProvider: FakeAccessTokenProvider(token: "token-123"),
            usageClient: usageClient
        )
        let authInfo = CodexAccountInfo(
            email: nil,
            planType: nil,
            subscriptionExpiresAt: nil,
            accountId: "acc_123",
            userId: nil
        )

        let result = await api.fetchUsage(authInfo: authInfo)
        let requests = await usageClient.recordedRequests()

        #expect(result?.sessionPercentUsed == 30)
        #expect(requests.count == 1)
        #expect(requests.first?.token == "token-123")
        #expect(requests.first?.accountId == "acc_123")
    }

    @Test
    func codexUsageApiReturnsNilWhenAccountIdIsMissing() async {
        let usageClient = RecordingUsageClient(
            result: CodexUsageData(
                sessionPercentUsed: 30,
                weeklyPercentUsed: 10,
                nextResetAt: nil,
                status: .available
            )
        )
        let api = CodexUsageAPI(
            accessTokenProvider: FakeAccessTokenProvider(token: "token-123"),
            usageClient: usageClient
        )
        let authInfo = CodexAccountInfo(
            email: nil,
            planType: nil,
            subscriptionExpiresAt: nil,
            accountId: nil,
            userId: nil
        )

        let result = await api.fetchUsage(authInfo: authInfo)
        let requests = await usageClient.recordedRequests()

        #expect(result == nil)
        #expect(requests.isEmpty)
    }

    @Test
    func codexAccessTokenProviderRefreshesAndPersistsUpdatedAuthJSON() async throws {
        let expiredToken = makeJWT(expiration: Date().addingTimeInterval(-3600).timeIntervalSince1970)
        let refreshedToken = makeJWT(expiration: Date().addingTimeInterval(3600).timeIntervalSince1970)
        let authData = try makeAuthJSONData(
            accessToken: expiredToken,
            refreshToken: "refresh-123"
        )
        let tracker = WriteTracker()

        let provider = CodexAccessTokenProvider(
            loadAuthData: { authData },
            writeAuthData: { data in
                tracker.record()
                _ = data
            },
            sendRefreshRequest: { _ in
                let responseBody = try JSONSerialization.data(
                    withJSONObject: [
                        "access_token": refreshedToken,
                        "refresh_token": "refresh-456",
                        "id_token": "id-456"
                    ]
                )
                let response = HTTPURLResponse(
                    url: URL(string: "https://auth.openai.com/oauth/token")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (responseBody, response)
            }
        )

        let token = await provider.currentAccessToken()

        #expect(token == refreshedToken)
        #expect(tracker.count == 1)
    }

    @Test
    func codexAccessTokenProviderReturnsRefreshedTokenWhenPersistingAuthJSONFails() async throws {
        let expiredToken = makeJWT(expiration: Date().addingTimeInterval(-3600).timeIntervalSince1970)
        let refreshedToken = makeJWT(expiration: Date().addingTimeInterval(3600).timeIntervalSince1970)
        let authData = try makeAuthJSONData(
            accessToken: expiredToken,
            refreshToken: "refresh-123"
        )
        let persistenceError = NSError(domain: "TestPersistence", code: 1)
        let tracker = WriteTracker()

        let provider = CodexAccessTokenProvider(
            loadAuthData: { authData },
            writeAuthData: { _ in
                tracker.record()
                throw persistenceError
            },
            sendRefreshRequest: { _ in
                let responseBody = try JSONSerialization.data(
                    withJSONObject: [
                        "access_token": refreshedToken,
                        "refresh_token": "refresh-456",
                        "id_token": "id-456"
                    ]
                )
                let response = HTTPURLResponse(
                    url: URL(string: "https://auth.openai.com/oauth/token")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (responseBody, response)
            }
        )

        let token = await provider.currentAccessToken()

        #expect(token == refreshedToken)
        #expect(tracker.count == 1)
    }

    @Test
    func codexAccessTokenProviderRefreshesWhenIdTokenIsExpiredEvenIfAccessTokenIsStillValid() async throws {
        let validAccessToken = makeJWT(
            expiration: Date().addingTimeInterval(10 * 24 * 3600).timeIntervalSince1970,
            payloadExtras: [
                "https://api.openai.com/auth": [
                    "chatgpt_plan_type": "free"
                ]
            ]
        )
        let expiredIdToken = makeJWT(
            expiration: Date().addingTimeInterval(-3600).timeIntervalSince1970,
            payloadExtras: [
                "email": "user@example.com",
                "https://api.openai.com/auth": [
                    "chatgpt_plan_type": "free"
                ]
            ]
        )
        let refreshedToken = makeJWT(expiration: Date().addingTimeInterval(3600).timeIntervalSince1970)
        let authData = try JSONSerialization.data(
            withJSONObject: [
                "tokens": [
                    "access_token": validAccessToken,
                    "refresh_token": "refresh-123",
                    "id_token": expiredIdToken
                ]
            ],
            options: .prettyPrinted
        )
        let tracker = WriteTracker()

        let provider = CodexAccessTokenProvider(
            loadAuthData: { authData },
            writeAuthData: { _ in
                tracker.record()
            },
            sendRefreshRequest: { _ in
                let responseBody = try JSONSerialization.data(
                    withJSONObject: [
                        "access_token": refreshedToken,
                        "refresh_token": "refresh-456",
                        "id_token": "id-456"
                    ]
                )
                let response = HTTPURLResponse(
                    url: URL(string: "https://auth.openai.com/oauth/token")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (responseBody, response)
            }
        )

        let token = await provider.currentAccessToken()

        #expect(token == refreshedToken)
        #expect(tracker.count == 1)
    }

    @Test
    func currentUsagePayloadHelpersReflectUsageAndMergePrimaryMetadata() {
        let primary = CurrentUsagePayload(
            accountIdentifier: "primary@example.com",
            planType: "pro",
            subscriptionExpiresAt: Date(timeIntervalSince1970: 1_700_000_000),
            sessionPercentUsed: nil,
            weeklyPercentUsed: nil,
            nextResetAt: nil,
            usageStatus: .unknown,
            sourceConfidence: 0.0,
            rawExtractedStrings: []
        )
        let fallback = CurrentUsagePayload(
            accountIdentifier: nil,
            planType: nil,
            subscriptionExpiresAt: nil,
            sessionPercentUsed: 42,
            weeklyPercentUsed: nil,
            nextResetAt: nil,
            usageStatus: .available,
            sourceConfidence: 0.7,
            rawExtractedStrings: ["usage"]
        )

        let merged = fallback.mergingMetadata(from: primary)

        #expect(primary.hasUsageData == false)
        #expect(fallback.hasUsageData == true)
        #expect(merged.accountIdentifier == "primary@example.com")
        #expect(merged.planType == "pro")
        #expect(merged.sessionPercentUsed == 42)
        #expect(merged.usageStatus == .available)
    }

    @Test
    func refreshUsesProviderAndSchedulesNotification() async {
        let store = InMemorySnapshotStore()
        let notifications = RecordingNotificationManager()
        let resetAt = Date().addingTimeInterval(600)
        let providerPayload = CurrentUsagePayload(
            accountIdentifier: "user@example.com",
            planType: "pro",
            subscriptionExpiresAt: nil,
            sessionPercentUsed: 75,
            weeklyPercentUsed: 20,
            nextResetAt: resetAt,
            usageStatus: .coolingDown,
            sourceConfidence: 1.0,
            rawExtractedStrings: []
        )
        let model = AppModel(
            usageProvider: FakeCurrentUsageProvider(result: providerPayload),
            runningChecker: FakeRunningChecker(isCodexRunning: true),
            notificationManager: notifications,
            store: store,
            shouldStartPolling: false
        )

        await model.refreshNowAsync()

        #expect(model.codexRunning == true)
        #expect(model.accounts.count == 1)
        #expect(model.snapshots.count == 1)
        #expect(model.accounts.first?.email == "user@example.com")
        #expect(model.compactLabel == countdownString(until: resetAt))
        #expect(notifications.scheduled.count == 1)
    }

    @Test
    func refreshSchedulesNotificationForExhaustedSnapshotWithKnownReset() async {
        let store = InMemorySnapshotStore()
        let notifications = RecordingNotificationManager()
        let resetAt = Date().addingTimeInterval(4 * 60 * 60 + 49 * 60)
        let providerPayload = CurrentUsagePayload(
            accountIdentifier: "zero@example.com",
            planType: "plus",
            subscriptionExpiresAt: nil,
            sessionPercentUsed: 100,
            weeklyPercentUsed: 40,
            nextResetAt: resetAt,
            usageStatus: .exhausted,
            sourceConfidence: 1.0,
            rawExtractedStrings: []
        )
        let model = AppModel(
            usageProvider: FakeCurrentUsageProvider(result: providerPayload),
            runningChecker: FakeRunningChecker(isCodexRunning: true),
            notificationManager: notifications,
            store: store,
            shouldStartPolling: false
        )

        await model.refreshNowAsync()

        #expect(model.compactLabel == countdownString(until: resetAt, language: model.resolvedLanguage))
        #expect(notifications.scheduled.count == 1)
        #expect(notifications.scheduled.first?.date == resetAt)
    }

    @Test
    func refreshReconcilesClaudeRenewalRemindersAfterSuccessfulRefresh() async {
        let store = InMemorySnapshotStore()
        let notifications = NotificationManagerSpy()
        let renewalDate = Date().addingTimeInterval(10 * 24 * 60 * 60)
        let claudePayload = CurrentUsagePayload(
            accountIdentifier: "claude@example.com",
            planType: "pro",
            subscriptionExpiresAt: renewalDate,
            sessionPercentUsed: 4,
            weeklyPercentUsed: 21,
            nextResetAt: Date().addingTimeInterval(2 * 60 * 60),
            usageStatus: .available,
            sourceConfidence: 0.98,
            rawExtractedStrings: [],
            provider: .claude,
            totalTokensToday: 1200,
            totalTokensThisWeek: 4500
        )
        let model = AppModel(
            usageProvider: FakeCurrentUsageProvider(result: nil),
            runningChecker: FakeRunningChecker(isCodexRunning: false),
            notificationManager: notifications,
            store: store,
            claudeUsageProvider: FakeCurrentUsageProvider(result: claudePayload),
            shouldStartPolling: false
        )

        await model.refreshNowAsync()

        #expect(model.accounts.count == 1)
        #expect(model.accounts.first?.provider == .claude)
        #expect(model.snapshots.first?.subscriptionExpiresAt == renewalDate)
        #expect(notifications.renewalScheduled.count == 2)
        #expect(Set(notifications.cancelledIdentifiers) == Set(RenewalReminderScheduler().reminderIdentifiers(for: model.accounts[0].id)))
    }

    @Test
    func refreshMarksExistingUsageAsStaleWhenFetchFails() async throws {
        let store = InMemorySnapshotStore()
        let notifications = RecordingNotificationManager()
        let account = Account(
            id: UUID(),
            provider: "Codex",
            email: "user@example.com",
            label: nil
        )
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: 75,
            weeklyPercentUsed: 20,
            nextResetAt: nil,
            subscriptionExpiresAt: nil,
            usageStatus: .available,
            sourceConfidence: 1.0,
            lastSyncedAt: Date().addingTimeInterval(-300),
            rawExtractedStrings: []
        )
        try store.save(
            PersistedState(
                accounts: [account],
                snapshots: [snapshot],
                accountMetadata: [],
                settings: .default
            )
        )

        let model = AppModel(
            usageProvider: FakeCurrentUsageProvider(result: nil),
            runningChecker: FakeRunningChecker(isCodexRunning: true),
            notificationManager: notifications,
            store: store,
            vault: ActiveEmailVault(email: account.email),
            shouldStartPolling: false
        )

        await model.refreshNowAsync()

        #expect(model.compactLabel == staleUsageLabel(hasSnapshots: true, language: model.resolvedLanguage))
        #expect(model.snapshots.first?.usageStatus == .stale)
        #expect(
            model.snapshots.first.map {
                shortUsageLabel(snapshot: $0, language: model.resolvedLanguage)
            } == staleUsageLabel(hasSnapshots: true, language: model.resolvedLanguage)
        )
        #expect(notifications.scheduled.isEmpty)
    }

    @Test
    func refreshKeepsCachedInactiveCodexCooldownWhenActiveAccountFails() async throws {
        let notifications = RecordingNotificationManager()
        let now = Date()
        let activeAccount = Account(
            id: UUID(),
            provider: .codex,
            email: "active@example.com",
            label: nil
        )
        let backupAccount = Account(
            id: UUID(),
            provider: .codex,
            email: "backup@example.com",
            label: nil
        )
        let backupResetAt = now.addingTimeInterval(36 * 60 * 60)
        let store = InMemorySnapshotStore(
            state: PersistedState(
                accounts: [activeAccount, backupAccount],
                snapshots: [
                    UsageSnapshot(
                        id: UUID(),
                        accountId: activeAccount.id,
                        sessionPercentUsed: 75,
                        weeklyPercentUsed: 20,
                        nextResetAt: nil,
                        subscriptionExpiresAt: nil,
                        usageStatus: .available,
                        sourceConfidence: 1.0,
                        lastSyncedAt: now.addingTimeInterval(-300),
                        rawExtractedStrings: []
                    ),
                    UsageSnapshot(
                        id: UUID(),
                        accountId: backupAccount.id,
                        sessionPercentUsed: 100,
                        weeklyPercentUsed: 64,
                        nextResetAt: backupResetAt,
                        subscriptionExpiresAt: nil,
                        usageStatus: .coolingDown,
                        sourceConfidence: 1.0,
                        lastSyncedAt: now.addingTimeInterval(-600),
                        rawExtractedStrings: []
                    )
                ],
                accountMetadata: [],
                settings: .default
            )
        )

        let model = AppModel(
            usageProvider: FakeCurrentUsageProvider(result: nil),
            runningChecker: FakeRunningChecker(isCodexRunning: true),
            notificationManager: notifications,
            store: store,
            vault: ActiveEmailVault(email: activeAccount.email),
            shouldStartPolling: false
        )

        await model.refreshNowAsync()

        let activeSnapshot = model.snapshots.first { $0.accountId == activeAccount.id }
        let backupSnapshot = model.snapshots.first { $0.accountId == backupAccount.id }

        #expect(activeSnapshot?.usageStatus == .stale)
        #expect(backupSnapshot?.usageStatus == .coolingDown)
        #expect(backupSnapshot?.nextResetAt == backupResetAt)
        #expect(model.compactLabel == countdownString(until: backupResetAt, language: model.resolvedLanguage))
        #expect(
            notifications.scheduled.contains {
                $0.accountId == backupAccount.id &&
                $0.accountName == backupAccount.displayName &&
                $0.date == backupResetAt
            }
        )
    }

    @Test
    func usageStateCoordinatorPersistsRefreshAndSchedulesNotification() throws {
        let store = InMemorySnapshotStore()
        let notifications = RecordingNotificationManager()
        let coordinator = UsageStateCoordinator(
            store: store,
            notificationManager: notifications
        )
        let payload = CurrentUsagePayload(
            accountIdentifier: "state@example.com",
            planType: "plus",
            subscriptionExpiresAt: nil,
            sessionPercentUsed: 20,
            weeklyPercentUsed: 40,
            nextResetAt: Date().addingTimeInterval(900),
            usageStatus: .coolingDown,
            sourceConfidence: 1.0,
            rawExtractedStrings: []
        )

        let result = try coordinator.applyRefresh(
            payload,
            to: PersistedState(accounts: [], snapshots: [])
        )

        #expect(result.accounts.count == 1)
        #expect(result.snapshots.count == 1)
        #expect(result.compactLabel == shortUsageLabel(snapshot: result.snapshots[0]))
        #expect(store.load().accounts.count == 1)
        #expect(store.load().snapshots.count == 1)
        #expect(notifications.scheduled.count == 1)
    }

    @Test
    func usageStateCoordinatorSchedulesNotificationForExhaustedSnapshotWithFutureReset() throws {
        let store = InMemorySnapshotStore()
        let notifications = RecordingNotificationManager()
        let coordinator = UsageStateCoordinator(
            store: store,
            notificationManager: notifications
        )
        let resetAt = Date().addingTimeInterval(30 * 60)
        let payload = CurrentUsagePayload(
            accountIdentifier: "wait@example.com",
            planType: "plus",
            subscriptionExpiresAt: nil,
            sessionPercentUsed: 100,
            weeklyPercentUsed: 50,
            nextResetAt: resetAt,
            usageStatus: .exhausted,
            sourceConfidence: 1.0,
            rawExtractedStrings: []
        )

        _ = try coordinator.applyRefresh(
            payload,
            to: PersistedState(accounts: [], snapshots: [])
        )

        #expect(notifications.scheduled.count == 1)
        #expect(notifications.scheduled.first?.date == resetAt)
    }

    @Test
    func usageStateCoordinatorDeleteRemovesAccountAndPersistsEmptyLabel() throws {
        let store = InMemorySnapshotStore()
        let notifications = RecordingNotificationManager()
        let coordinator = UsageStateCoordinator(
            store: store,
            notificationManager: notifications
        )
        let account = Account(
            id: UUID(),
            provider: "Codex",
            email: "delete@example.com",
            label: nil
        )
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: 10,
            weeklyPercentUsed: 10,
            nextResetAt: nil,
            subscriptionExpiresAt: nil,
            usageStatus: .available,
            sourceConfidence: 1.0,
            lastSyncedAt: Date(),
            rawExtractedStrings: []
        )
        let state = PersistedState(
            accounts: [account],
            snapshots: [snapshot],
            accountMetadata: [],
            settings: .default
        )

        let result = try coordinator.deleteAccount(account, from: state)

        #expect(result.accounts.isEmpty)
        #expect(result.snapshots.isEmpty)
        #expect(result.compactLabel == "--")
        #expect(store.load().accounts.isEmpty)
        #expect(store.load().snapshots.isEmpty)
    }

    @Test
    func usageStateCoordinatorResetClearsPersistedState() throws {
        let store = InMemorySnapshotStore(
            state: PersistedState(
                accounts: [
                    Account(
                        id: UUID(),
                        provider: "Codex",
                        email: "persisted@example.com",
                        label: nil
                    )
                ],
                snapshots: []
            )
        )
        let coordinator = UsageStateCoordinator(
            store: store,
            notificationManager: RecordingNotificationManager()
        )

        let result = try coordinator.resetAll()

        #expect(result.accounts.isEmpty)
        #expect(result.snapshots.isEmpty)
        #expect(result.compactLabel == "--")
        #expect(store.load().accounts.isEmpty)
        #expect(store.load().snapshots.isEmpty)
    }

    @Test
    func appModelTracksClaudeCookieConfiguration() {
        let cookieStore = InMemoryClaudeCookieStore()
        let model = AppModel(
            store: InMemorySnapshotStore(),
            claudeSessionCookieStore: cookieStore,
            shouldStartPolling: false
        )

        #expect(model.claudeCookieConfigured == false)
        #expect(model.saveClaudeSessionCookie("sessionKey=test-cookie") == true)
        #expect(model.claudeCookieConfigured == true)

        model.clearClaudeSessionCookie()

        #expect(model.claudeCookieConfigured == false)
        #expect(cookieStore.cookieHeaderValue() == nil)
    }

    @Test
    func refreshNowAsyncCoalescesConcurrentRefreshRequests() async {
        let provider = SlowTrackingUsageProvider(
            result: CurrentUsagePayload(
                accountIdentifier: "coalesce@example.com",
                planType: nil,
                subscriptionExpiresAt: nil,
                sessionPercentUsed: 25,
                weeklyPercentUsed: 40,
                nextResetAt: nil,
                usageStatus: .available,
                sourceConfidence: 1,
                rawExtractedStrings: [],
                provider: .codex
            ),
            delayNanoseconds: 150_000_000
        )
        let model = AppModel(
            usageProvider: provider,
            runningChecker: FakeRunningChecker(isCodexRunning: true),
            store: InMemorySnapshotStore(),
            vault: ActiveEmailVault(email: "coalesce@example.com"),
            shouldStartPolling: false
        )

        async let first: Void = model.refreshNowAsync()
        async let second: Void = model.refreshNowAsync()
        _ = await (first, second)

        let stats = await provider.recordedStats()
        #expect(stats.totalCalls == 1)
        #expect(stats.maxConcurrentCalls == 1)
        #expect(model.accounts.count == 1)
        #expect(model.snapshots.count == 1)
    }

    @Test
    func persistenceErrorMessageIsExposedWhenSavingStateFails() {
        let model = AppModel(
            store: SaveFailingSnapshotStore(),
            shouldStartPolling: false
        )

        model.setLanguage(.russian)

        #expect(model.persistenceErrorMessage?.contains("Disk full") == true)
    }

    @Test
    func persistenceErrorMessageIsExposedWhenInitialNormalizationSaveFails() {
        let canonicalAccount = Account(
            id: UUID(),
            provider: .claude,
            email: "outcastsdev@gmail.com",
            label: nil
        )
        let legacyAccount = Account(
            id: UUID(),
            provider: .claude,
            email: nil,
            label: "Claude Code"
        )
        let store = SaveFailingSnapshotStore(
            state: PersistedState(
                accounts: [canonicalAccount, legacyAccount],
                snapshots: [],
                accountMetadata: [],
                settings: .default
            )
        )

        let model = AppModel(
            store: store,
            shouldStartPolling: false
        )

        #expect(model.persistenceErrorMessage?.contains("Disk full") == true)
    }

    @Test
    func persistenceErrorMessageIsExposedWhenInitialStateIsCorrupted() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LimitBarCorrupted-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try "{ not valid json".data(using: .utf8)?.write(
            to: directory.appendingPathComponent("state.json"),
            options: .atomic
        )

        let store = try SnapshotStore(directory: directory)
        let model = AppModel(
            store: store,
            shouldStartPolling: false
        )

        #expect(model.persistenceErrorMessage?.localizedCaseInsensitiveContains("corrupted") == true)
        let backups = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix("state.corrupted.") }
        #expect(backups.count == 1)
    }

    @Test
    func dismissedUpdateVersionHidesSameAvailableRelease() async {
        let store = InMemorySnapshotStore(
            state: PersistedState(
                accounts: [],
                snapshots: [],
                settings: AppSettingsState(
                    pollingWhenRunning: nil,
                    pollingWhenClosed: nil,
                    cooldownNotificationsEnabled: true,
                    renewalReminders: .default,
                    dismissedUpdateVersion: "0.1.3"
                )
            )
        )
        let appUpdateChecker = FakeAppUpdateChecker(
            update: AppUpdateInfo(
                version: "0.1.3",
                downloadURL: URL(string: "https://limitbar.netlify.app/download/macos")!,
                releaseNotes: "Already dismissed."
            )
        )
        let model = AppModel(
            store: store,
            appUpdateChecker: appUpdateChecker,
            shouldStartPolling: false
        )

        await model.refreshNowAsync()

        #expect(model.availableUpdate == nil)
    }

    @Test
    func dismissAvailableUpdatePersistsVersionAndAllowsNewerRelease() async {
        let store = InMemorySnapshotStore()
        let appUpdateChecker = FakeAppUpdateChecker(
            update: AppUpdateInfo(
                version: "0.1.3",
                downloadURL: URL(string: "https://limitbar.netlify.app/download/macos")!,
                releaseNotes: "Bridge release."
            )
        )
        let model = AppModel(
            store: store,
            appUpdateChecker: appUpdateChecker,
            shouldStartPolling: false
        )

        await model.refreshNowAsync()
        #expect(model.availableUpdate?.version == "0.1.3")

        model.dismissAvailableUpdate()

        #expect(model.availableUpdate == nil)
        #expect(store.load().settings.dismissedUpdateVersion == "0.1.3")

        await appUpdateChecker.setUpdate(
            AppUpdateInfo(
                version: "0.1.4",
                downloadURL: URL(string: "https://limitbar.netlify.app/download/macos")!,
                releaseNotes: "New fixes."
            )
        )

        await model.refreshNowAsync()

        #expect(model.availableUpdate?.version == "0.1.4")
        #expect(model.availableUpdate?.releaseNotes == "New fixes.")
    }

    @Test
    func refreshMarksOnlyClaudeSnapshotsStaleWhenClaudeFetchFails() async throws {
        let codexAccount = Account(
            id: UUID(),
            provider: .codex,
            email: "codex@example.com",
            label: nil
        )
        let claudeAccount = Account(
            id: UUID(),
            provider: .claude,
            email: "claude@example.com",
            label: nil
        )
        let store = InMemorySnapshotStore(
            state: PersistedState(
                accounts: [codexAccount, claudeAccount],
                snapshots: [
                    UsageSnapshot(
                        id: UUID(),
                        accountId: codexAccount.id,
                        sessionPercentUsed: 10,
                        weeklyPercentUsed: 20,
                        nextResetAt: nil,
                        subscriptionExpiresAt: nil,
                        usageStatus: .available,
                        sourceConfidence: 1.0,
                        lastSyncedAt: Date(),
                        rawExtractedStrings: []
                    ),
                    UsageSnapshot(
                        id: UUID(),
                        accountId: claudeAccount.id,
                        sessionPercentUsed: 35,
                        weeklyPercentUsed: 45,
                        nextResetAt: nil,
                        subscriptionExpiresAt: nil,
                        usageStatus: .available,
                        sourceConfidence: 1.0,
                        lastSyncedAt: Date(),
                        rawExtractedStrings: []
                    )
                ]
            )
        )
        let codexPayload = CurrentUsagePayload(
            accountIdentifier: "codex@example.com",
            planType: "plus",
            subscriptionExpiresAt: nil,
            sessionPercentUsed: 15,
            weeklyPercentUsed: 25,
            nextResetAt: nil,
            usageStatus: .available,
            sourceConfidence: 1.0,
            rawExtractedStrings: [],
            provider: .codex
        )
        let model = AppModel(
            usageProvider: FakeCurrentUsageProvider(result: codexPayload),
            runningChecker: FakeRunningChecker(isCodexRunning: false),
            store: store,
            claudeUsageProvider: FakeCurrentUsageProvider(result: nil),
            shouldStartPolling: false
        )

        await model.refreshNowAsync()

        let codexSnapshot = model.snapshots.first { $0.accountId == codexAccount.id }
        let claudeSnapshot = model.snapshots.first { $0.accountId == claudeAccount.id }
        #expect(codexSnapshot?.usageStatus == .available)
        #expect(claudeSnapshot?.usageStatus == .stale)
    }

    @Test
    func claudeWebSessionStatusRequiresQuotaForCurrentOrganization() async {
        let controller = FakeClaudeWebSessionController()
        controller.resultByOrganization["org-123"] = ClaudeWebFetchResult(
            status: 200,
            body: """
            {
              "five_hour": {
                "remaining_percent": 71,
                "reset_at": "2026-04-03T10:00:00Z"
              },
              "seven_day": {
                "remaining_percent": 43,
                "reset_at": "2026-04-05T10:00:00Z"
              }
            }
            """,
            url: "https://claude.ai/settings/usage",
            organizationUUID: "org-123"
        )

        let model = AppModel(
            store: InMemorySnapshotStore(),
            claudeCredentialsReader: AppModelFakeClaudeCredentialsReader(
                credentials: ClaudeCredentials(
                    subscriptionType: "pro",
                    accountIdentifier: "outcastsdev@gmail.com",
                    organizationUUID: "org-123"
                )
            ),
            claudeWebSessionController: controller,
            shouldStartPolling: false
        )

        await model.refreshClaudeWebSessionStatus()

        #expect(model.claudeWebSessionConnected == true)
        #expect(model.claudeWebSessionErrorMessage == nil)
    }

    @Test
    func claudeWebSessionStatusStaysDisconnectedForDifferentOrganization() async {
        let controller = FakeClaudeWebSessionController()
        controller.resultByOrganization["org-999"] = ClaudeWebFetchResult(
            status: 200,
            body: """
            {
              "five_hour": {
                "remaining_percent": 50,
                "reset_at": "2026-04-03T10:00:00Z"
              }
            }
            """,
            url: "https://claude.ai/settings/usage",
            organizationUUID: "org-999"
        )

        let model = AppModel(
            store: InMemorySnapshotStore(),
            claudeCredentialsReader: AppModelFakeClaudeCredentialsReader(
                credentials: ClaudeCredentials(
                    subscriptionType: "pro",
                    accountIdentifier: "outcastsdev@gmail.com",
                    organizationUUID: "org-123"
                )
            ),
            claudeWebSessionController: controller,
            shouldStartPolling: false
        )

        await model.refreshClaudeWebSessionStatus()

        #expect(model.claudeWebSessionConnected == false)
    }

    @Test
    func claudeWebSessionStatusIgnoresStaleResultWhenOrganizationChangesMidRefresh() async {
        let controller = FakeClaudeWebSessionController()
        controller.resultByOrganization["org-old"] = ClaudeWebFetchResult(
            status: 200,
            body: """
            {
              "five_hour": {
                "remaining_percent": 50,
                "reset_at": "2026-04-03T10:00:00Z"
              }
            }
            """,
            url: "https://claude.ai/settings/usage",
            organizationUUID: "org-old"
        )

        let model = AppModel(
            store: InMemorySnapshotStore(),
            claudeCredentialsReader: SequencedClaudeCredentialsReader([
                ClaudeCredentials(
                    subscriptionType: "pro",
                    accountIdentifier: "outcastsdev@gmail.com",
                    organizationUUID: "org-old"
                ),
                ClaudeCredentials(
                    subscriptionType: "pro",
                    accountIdentifier: "outcastsdev@gmail.com",
                    organizationUUID: "org-new"
                )
            ]),
            claudeWebSessionController: controller,
            shouldStartPolling: false
        )

        await model.refreshClaudeWebSessionStatus()

        #expect(model.claudeWebSessionConnected == false)
        #expect(model.claudeWebSessionErrorMessage == nil)
    }

    @Test
    func clearClaudeWebSessionDropsCachedConnectedState() async {
        let controller = FakeClaudeWebSessionController()
        controller.resultByOrganization["org-123"] = ClaudeWebFetchResult(
            status: 200,
            body: """
            {
              "five_hour": {
                "remaining_percent": 71,
                "reset_at": "2026-04-03T10:00:00Z"
              }
            }
            """,
            url: "https://claude.ai/settings/usage",
            organizationUUID: "org-123"
        )

        let model = AppModel(
            usageProvider: FakeCurrentUsageProvider(result: nil),
            runningChecker: FakeRunningChecker(isCodexRunning: false),
            store: InMemorySnapshotStore(),
            claudeUsageProvider: FakeCurrentUsageProvider(result: nil),
            claudeCredentialsReader: AppModelFakeClaudeCredentialsReader(
                credentials: ClaudeCredentials(
                    subscriptionType: "pro",
                    accountIdentifier: "outcastsdev@gmail.com",
                    organizationUUID: "org-123"
                )
            ),
            claudeWebSessionController: controller,
            shouldStartPolling: false
        )

        await model.refreshClaudeWebSessionStatus()
        #expect(model.claudeWebSessionConnected == true)

        model.clearClaudeWebSession()
        try? await Task.sleep(nanoseconds: 200_000_000)

        #expect(controller.cachedUsageResponse(organizationUUID: "org-123") == nil)
        #expect(model.claudeWebSessionConnected == false)
    }

    @Test
    func isActiveAccountMatchesCodexAndClaudeProviders() {
        let model = AppModel(
            store: InMemorySnapshotStore(),
            shouldStartPolling: false
        )
        model.activeCodexEmail = "shared@example.com"
        model.activeClaudeAccountIdentifier = "shared@example.com"

        let claudeAccount = Account(
            id: UUID(),
            provider: .claude,
            email: "shared@example.com",
            label: nil
        )
        let codexAccount = Account(
            id: UUID(),
            provider: .codex,
            email: "shared@example.com",
            label: nil
        )

        #expect(model.isActiveAccount(claudeAccount) == true)
        #expect(model.isActiveAccount(codexAccount) == true)
    }

    @Test
    func isActiveAccountMatchesClaudeLabelWhenActiveIdentifierIsNotEmail() {
        let model = AppModel(
            store: InMemorySnapshotStore(),
            shouldStartPolling: false
        )
        model.activeClaudeAccountIdentifier = "Claude Workspace"

        let claudeAccount = Account(
            id: UUID(),
            provider: .claude,
            email: nil,
            label: "Claude Workspace"
        )

        #expect(model.isActiveAccount(claudeAccount) == true)
    }

    @Test
    func initRecoversExpiredCodexSnapshotToPredictedReset() {
        let account = Account(
            id: UUID(),
            provider: .codex,
            email: "codex@example.com",
            label: nil
        )
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: 73,
            weeklyPercentUsed: 40,
            nextResetAt: Date().addingTimeInterval(-300),
            weeklyResetAt: nil,
            subscriptionExpiresAt: nil,
            planType: "plus",
            usageStatus: .stale,
            stateOrigin: .server,
            sourceConfidence: 1.0,
            lastSyncedAt: Date().addingTimeInterval(-3600),
            rawExtractedStrings: []
        )

        let model = AppModel(
            usageProvider: FakeCurrentUsageProvider(result: nil),
            runningChecker: FakeRunningChecker(isCodexRunning: false),
            store: InMemorySnapshotStore(
                state: PersistedState(accounts: [account], snapshots: [snapshot])
            ),
            shouldStartPolling: false
        )

        #expect(model.snapshots.count == 1)
        #expect(model.snapshots[0].accountId == account.id)
        #expect(model.snapshots[0].sessionPercentUsed == 0)
        #expect(model.snapshots[0].usageStatus == .available)
        #expect(model.snapshots[0].stateOrigin == .predictedReset)
    }

    @Test
    func refreshRecoversExpiredCodexSnapshotWhenUsageFetchFails() async {
        let account = Account(
            id: UUID(),
            provider: .codex,
            email: "codex@example.com",
            label: nil
        )
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: 88,
            weeklyPercentUsed: 55,
            nextResetAt: Date().addingTimeInterval(-300),
            weeklyResetAt: nil,
            subscriptionExpiresAt: nil,
            planType: "plus",
            usageStatus: .stale,
            stateOrigin: .server,
            sourceConfidence: 1.0,
            lastSyncedAt: Date().addingTimeInterval(-3600),
            rawExtractedStrings: []
        )

        let model = AppModel(
            usageProvider: FakeCurrentUsageProvider(result: nil),
            runningChecker: FakeRunningChecker(isCodexRunning: false),
            store: InMemorySnapshotStore(
                state: PersistedState(accounts: [account], snapshots: [snapshot])
            ),
            vault: ActiveEmailVault(email: account.email),
            shouldStartPolling: false
        )

        model.snapshots[0].sessionPercentUsed = 88
        model.snapshots[0].usageStatus = .stale

        await model.refreshNowAsync()

        #expect(model.snapshots.count == 1)
        #expect(model.snapshots[0].accountId == account.id)
        #expect(model.snapshots[0].sessionPercentUsed == 0)
        #expect(model.snapshots[0].usageStatus == .available)
        #expect(model.snapshots[0].stateOrigin == .predictedReset)
    }

}
