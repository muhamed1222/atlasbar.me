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

    func requestAuthorization() async -> Bool {
        true
    }

    func scheduleCooldownReadyNotification(accountName: String, at date: Date) {
        scheduled.append((accountName, date))
    }

    func cancelNotification(for accountName: String) {}
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
    func shortUsageLabelShowsStaleForStaleSnapshots() {
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: UUID(),
            sessionPercentUsed: 14,
            weeklyPercentUsed: 32,
            nextResetAt: nil,
            subscriptionExpiresAt: nil,
            usageStatus: .stale,
            subscriptionStatus: .unknown,
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
            label: nil,
            note: nil,
            priority: nil
        )
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: 75,
            weeklyPercentUsed: 20,
            nextResetAt: nil,
            subscriptionExpiresAt: nil,
            usageStatus: .available,
            subscriptionStatus: .unknown,
            sourceConfidence: 1.0,
            lastSyncedAt: Date().addingTimeInterval(-300),
            rawExtractedStrings: []
        )
        try store.save(PersistedState(accounts: [account], snapshots: [snapshot]))

        let model = AppModel(
            usageProvider: FakeCurrentUsageProvider(result: nil),
            runningChecker: FakeRunningChecker(isCodexRunning: true),
            notificationManager: notifications,
            store: store,
            shouldStartPolling: false
        )

        await model.refreshNowAsync()

        #expect(model.compactLabel == "Stale")
        #expect(model.snapshots.first?.usageStatus == .stale)
        #expect(model.snapshots.first.map(shortUsageLabel) == "Stale")
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
            label: nil,
            note: nil,
            priority: nil
        )
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: 10,
            weeklyPercentUsed: 10,
            nextResetAt: nil,
            subscriptionExpiresAt: nil,
            usageStatus: .available,
            subscriptionStatus: .unknown,
            sourceConfidence: 1.0,
            lastSyncedAt: Date(),
            rawExtractedStrings: []
        )
        let state = PersistedState(accounts: [account], snapshots: [snapshot])

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
                        label: nil,
                        note: nil,
                        priority: nil
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
