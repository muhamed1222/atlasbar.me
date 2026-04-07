import Testing
import Foundation
import WebKit
@testable import LimitBar

private final class StartupTestSnapshotStore: @unchecked Sendable, SnapshotStoring {
    private var state: PersistedState
    var lastLoadIssue: String?

    init(state: PersistedState) {
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

private final class StartupTestNotificationManager: @unchecked Sendable, NotificationScheduling {
    private(set) var scheduled: [(accountId: UUID, accountName: String, date: Date)] = []
    private(set) var cancelled: [(accountId: UUID, accountName: String)] = []
    private(set) var renewalScheduled: [(identifier: String, accountName: String, date: Date)] = []
    private(set) var cancelledIdentifiers: [String] = []

    func requestAuthorization() async -> Bool { true }

    func scheduleCooldownReadyNotification(accountId: UUID, accountName: String, at date: Date) {
        scheduled.append((accountId, accountName, date))
    }

    func cancelCooldownReadyNotification(accountId: UUID, accountName: String) {
        cancelled.append((accountId, accountName))
    }

    func cancelNotifications(withIdentifiers identifiers: [String]) {
        cancelledIdentifiers.append(contentsOf: identifiers)
    }

    func scheduleRenewalReminder(identifier: String, accountName: String, at date: Date) {
        renewalScheduled.append((identifier, accountName, date))
    }

    func scheduleNotification(
        identifier: String,
        title: String,
        body: String,
        at date: Date
    ) {
        _ = (identifier, title, body, date)
    }
}

private struct ClaudeSessionPipelineStub: ClaudeUsagePipelining {
    let status: ClaudeWebSessionStatusProjection?

    func fetchCurrentUsage() async -> CurrentUsagePayload? { nil }
    func refreshWebSessionStatus() async -> ClaudeWebSessionStatusProjection? { status }
    func cachedWebSessionStatus() async -> ClaudeWebSessionStatusProjection? { status }
}

private struct ClaudeSessionCredentialsReaderStub: ClaudeCredentialsReading {
    let credentials: ClaudeCredentials?

    func readCredentials() -> ClaudeCredentials? {
        credentials
    }
}

private final class ClaudeSessionCookieStoreStub: @unchecked Sendable, ClaudeSessionCookieStoring {
    private(set) var cookie: String?
    var saveError: (any Error)?
    var clearError: (any Error)?

    func hasStoredCookie() -> Bool {
        cookie?.isEmpty == false
    }

    func cookieHeaderValue() -> String? {
        cookie
    }

    func saveCookie(_ rawValue: String) throws {
        if let saveError { throw saveError }
        cookie = rawValue
    }

    func clearCookie() throws {
        if let clearError { throw clearError }
        cookie = nil
    }
}

@MainActor
private final class ClaudeSessionControllerStub: ClaudeWebSessionControlling {
    var webView: WKWebView { WKWebView(frame: .zero) }
    var preparedLoginPage = false
    var clearedSession = false
    var resultByOrganization: [String: ClaudeWebFetchResult] = [:]
    var subscriptionResultByOrganization: [String: ClaudeWebFetchResult] = [:]

    func prepareLoginPage() {
        preparedLoginPage = true
    }

    func clearSession() async throws {
        clearedSession = true
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

struct AppStartupAndClaudeSessionRuntimeTests {
    @Test
    func stateSideEffectsRuntimePersistsStateAndReconcilesNotifications() throws {
        let account = Account(id: UUID(), provider: .codex, email: "effects@example.com", label: nil)
        let now = Date()
        let state = PersistedState(
            accounts: [account],
            snapshots: [
                UsageSnapshot(
                    id: UUID(),
                    accountId: account.id,
                    sessionPercentUsed: 100,
                    weeklyPercentUsed: 40,
                    nextResetAt: now.addingTimeInterval(45 * 60),
                    weeklyResetAt: nil,
                    subscriptionExpiresAt: now.addingTimeInterval(5 * 24 * 60 * 60),
                    planType: "plus",
                    usageStatus: .coolingDown,
                    stateOrigin: .server,
                    sourceConfidence: 1,
                    lastSyncedAt: now.addingTimeInterval(-60),
                    rawExtractedStrings: []
                )
            ],
            settings: .default
        )
        let store = StartupTestSnapshotStore(
            state: PersistedState(accounts: [], snapshots: [])
        )
        let notifications = StartupTestNotificationManager()
        let runtime = AppStateSideEffectsRuntime(
            store: store,
            notificationManager: notifications
        )

        try runtime.persist(state)
        runtime.reconcileNotifications(in: state, now: now)

        #expect(store.load() == state)
        #expect(notifications.scheduled.count == 1)
        #expect(notifications.scheduled.first?.accountId == account.id)
        #expect(notifications.renewalScheduled.count == 2)
    }

    @Test
    func stateSideEffectsRuntimeCancelsNotificationsForAccounts() {
        let account = Account(id: UUID(), provider: .codex, email: "cancel@example.com", label: nil)
        let notifications = StartupTestNotificationManager()
        let runtime = AppStateSideEffectsRuntime(
            store: nil,
            notificationManager: notifications
        )

        runtime.cancelNotifications(for: [account])
        runtime.cancelRenewalReminders(for: [account])

        #expect(notifications.cancelled.count == 1)
        #expect(notifications.cancelled.first?.accountId == account.id)
        #expect(
            Set(notifications.cancelledIdentifiers) ==
            Set(RenewalReminderScheduler().reminderIdentifiers(for: account.id))
        )
    }

    @Test
    func startupRuntimeRecoversExpiredResetsAndPersistsRecoveredSnapshot() {
        let account = Account(id: UUID(), provider: .codex, email: "codex@example.com", label: nil)
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: 82,
            weeklyPercentUsed: 45,
            nextResetAt: Date(timeIntervalSince1970: 1_000),
            weeklyResetAt: nil,
            subscriptionExpiresAt: nil,
            planType: "plus",
            usageStatus: .stale,
            stateOrigin: .server,
            sourceConfidence: 1,
            lastSyncedAt: Date(timeIntervalSince1970: 900),
            rawExtractedStrings: []
        )
        let store = StartupTestSnapshotStore(
            state: PersistedState(accounts: [account], snapshots: [snapshot])
        )
        let notifications = StartupTestNotificationManager()
        let runtime = AppStartupRuntime(
            stateCoordinator: UsageStateCoordinator(store: store, notificationManager: notifications),
            notificationManager: notifications,
            store: store
        )

        let projection = runtime.bootstrap(now: Date(timeIntervalSince1970: 1_100))

        #expect(projection.snapshots.count == 1)
        #expect(projection.snapshots[0].sessionPercentUsed == 0)
        #expect(projection.snapshots[0].usageStatus == .available)
        #expect(projection.snapshots[0].stateOrigin == .predictedReset)
        #expect(store.load().snapshots[0].stateOrigin == .predictedReset)
    }

    @Test
    func startupRuntimeReconcilesPersistedCooldownNotifications() {
        let account = Account(id: UUID(), provider: .codex, email: "cooldown@example.com", label: nil)
        let now = Date()
        let resetAt = now.addingTimeInterval(30 * 60)
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: 100,
            weeklyPercentUsed: 70,
            nextResetAt: resetAt,
            weeklyResetAt: nil,
            subscriptionExpiresAt: nil,
            planType: "plus",
            usageStatus: .coolingDown,
            stateOrigin: .server,
            sourceConfidence: 1,
            lastSyncedAt: now.addingTimeInterval(-5 * 60),
            rawExtractedStrings: []
        )
        let store = StartupTestSnapshotStore(
            state: PersistedState(accounts: [account], snapshots: [snapshot])
        )
        let notifications = StartupTestNotificationManager()
        let runtime = AppStartupRuntime(
            stateCoordinator: UsageStateCoordinator(store: store, notificationManager: notifications),
            notificationManager: notifications,
            store: store
        )

        _ = runtime.bootstrap(now: now)

        #expect(notifications.scheduled.count == 1)
        let scheduled = notifications.scheduled.first
        #expect(scheduled?.accountId == account.id)
        #expect(scheduled?.date == resetAt)
    }

    @Test
    @MainActor
    func claudeSessionRuntimeUsesPipelineStatusWhenAvailable() async {
        let runtime = ClaudeSessionRuntime(
            pipeline: ClaudeSessionPipelineStub(
                status: ClaudeWebSessionStatusProjection(isConnected: true, errorMessage: nil)
            ),
            credentialsReader: ClaudeSessionCredentialsReaderStub(credentials: nil),
            cookieStore: nil,
            webSessionController: nil
        )

        let status = await runtime.refreshWebSessionStatus()

        #expect(status == ClaudeWebSessionStatusProjection(isConnected: true, errorMessage: nil))
    }

    @Test
    @MainActor
    func claudeSessionRuntimeUpdatesCookieStateAndClearsWebSession() async {
        let cookieStore = ClaudeSessionCookieStoreStub()
        let controller = ClaudeSessionControllerStub()
        let runtime = ClaudeSessionRuntime(
            pipeline: nil,
            credentialsReader: ClaudeSessionCredentialsReaderStub(
                credentials: ClaudeCredentials(
                    subscriptionType: "pro",
                    accountIdentifier: "claude@example.com",
                    organizationUUID: "org-123"
                )
            ),
            cookieStore: cookieStore,
            webSessionController: controller
        )

        let saved = runtime.saveCookie("sessionKey=test-cookie")
        let clearedCookie = runtime.clearCookie()
        let clearedSession = await runtime.clearWebSession()
        let didClearControllerSession = controller.clearedSession

        #expect(saved.isConfigured == true)
        #expect(saved.errorMessage == nil)
        #expect(saved.shouldRefreshUsage == true)
        #expect(clearedCookie.isConfigured == false)
        #expect(clearedCookie.errorMessage == nil)
        #expect(clearedCookie.shouldRefreshUsage == true)
        #expect(clearedSession.didClearSession == true)
        #expect(clearedSession.errorMessage == nil)
        #expect(clearedSession.shouldRefreshUsage == true)
        #expect(didClearControllerSession == true)
    }
}
