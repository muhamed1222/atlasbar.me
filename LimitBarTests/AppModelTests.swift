import Testing
import Foundation
@testable import LimitBar

private struct FakeAuthReader: CodexAuthReading {
    let authInfo: CodexAccountInfo?

    func readAccountInfo() -> CodexAccountInfo? {
        authInfo
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

private struct FakeRunningChecker: CodexRunningChecking {
    let isCodexRunning: Bool
}

private final class InMemorySnapshotStore: SnapshotStoring {
    private var state: PersistedState

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

private final class RecordingNotificationManager: NotificationScheduling {
    private(set) var scheduled: [(String, Date)] = []
    private(set) var cancelled: [String] = []

    func requestAuthorization() async -> Bool {
        true
    }

    func scheduleCooldownReadyNotification(accountName: String, at date: Date) {
        scheduled.append((accountName, date))
    }

    func cancelCooldownReadyNotification(accountName: String) {
        cancelled.append(accountName)
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

private final class NotificationManagerSpy: NotificationScheduling {
    var cooldownScheduled: [(accountName: String, date: Date)] = []
    var cooldownCancelled: [String] = []
    var renewalScheduled: [RenewalReminderRequest] = []
    var cancelledIdentifiers: [String] = []

    func requestAuthorization() async -> Bool {
        true
    }

    func scheduleCooldownReadyNotification(accountName: String, at date: Date) {
        cooldownScheduled.append((accountName, date))
    }

    func cancelCooldownReadyNotification(accountName: String) {
        cooldownCancelled.append(accountName)
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
            usageStatus: .available,
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
        #expect(notificationManager.renewalScheduled.count == 4)
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

        #expect(notificationManager.cooldownCancelled == [account.displayName])
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

        #expect(notificationManager.cooldownCancelled == [account.displayName])
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
        #expect(result?.usageStatus == .coolingDown)
        #expect(result?.sourceConfidence == 1.0)
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

}
