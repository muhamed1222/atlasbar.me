import Foundation
import OSLog
import AppKit
import WebKit

private let logger = Logger(subsystem: "me.atlasbar.LimitBar", category: "AppModel")

private enum AppRuntimeDefaults {
    static var shouldStartPolling: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var compactLabel: String = "--"
    @Published var menuBarState: MenuBarState = .noData
    @Published var codexRunning: Bool = false
    @Published var lastRefreshAt: Date?
    @Published var accounts: [Account] = []
    @Published var snapshots: [UsageSnapshot] = []
    @Published var accountMetadata: [AccountMetadata] = []
    @Published var settings: AppSettingsState = .default
    @Published var activeCodexEmail: String?
    @Published var activeClaudeAccountIdentifier: String?
    @Published var switchingAccountId: UUID?
    @Published var switchErrorMessage: String?
    @Published var claudeCookieConfigured: Bool = false
    @Published var claudeCookieErrorMessage: String?
    @Published var claudeWebSessionConnected: Bool = false
    @Published var claudeWebSessionErrorMessage: String?
    @Published var persistenceErrorMessage: String?
    @Published var availableUpdate: AppUpdateInfo?

    var resolvedLanguage: ResolvedAppLanguage {
        settings.language.resolved()
    }

    var strings: AppStrings {
        AppStrings(language: resolvedLanguage)
    }

    var appLocale: Locale {
        resolvedLanguage.locale
    }

    private let claudeUsageProvider: (any CurrentUsageProviding)?
    private let pollingCoordinator: PollingCoordinator
    private let stateCoordinator: UsageStateCoordinator
    private let refreshEngine: RefreshEngine
    private let startupRuntime: AppStartupRuntime
    private let sideEffectsRuntime: AppStateSideEffectsRuntime
    private let claudeSessionRuntime: ClaudeSessionRuntime
    private let presentationRuntime: AppPresentationRuntime
    private let accountSessionStateRuntime: AccountSessionStateRuntime
    private let accountSwitchRuntime: AccountSwitchRuntime
    private let appUpdateChecker: any AppUpdateChecking
    private let settingsCoordinator = SettingsCoordinator()
    private let vault: any AccountVaulting
    private let sessionSwitcher: any CodexSessionSwitching
    private var timerTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?

    init(
        usageProvider: any CurrentUsageProviding = APIBasedUsageProvider(),
        runningChecker: any CodexRunningChecking = ProcessWatcher(),
        pollingCoordinator: PollingCoordinator = PollingCoordinator(),
        notificationManager: any NotificationScheduling = NotificationManager(),
        store: (any SnapshotStoring)? = nil,
        vault: (any AccountVaulting)? = nil,
        sessionSwitcher: (any CodexSessionSwitching)? = nil,
        claudeUsageProvider: (any CurrentUsageProviding)? = nil,
        claudeUsagePipeline: (any ClaudeUsagePipelining)? = nil,
        claudeCredentialsReader: (any ClaudeCredentialsReading)? = nil,
        claudeSessionCookieStore: (any ClaudeSessionCookieStoring)? = nil,
        claudeWebSessionController: (any ClaudeWebSessionControlling)? = nil,
        appUpdateChecker: (any AppUpdateChecking)? = nil,
        shouldStartPolling: Bool = AppRuntimeDefaults.shouldStartPolling
    ) {
        self.claudeUsageProvider = claudeUsageProvider ?? claudeUsagePipeline
        self.pollingCoordinator = pollingCoordinator
        self.vault = vault ?? AccountVault()
        self.sessionSwitcher = sessionSwitcher ?? CodexSessionSwitcher(vault: self.vault)
        self.accountSwitchRuntime = AccountSwitchRuntime(sessionSwitcher: self.sessionSwitcher)
        self.appUpdateChecker = appUpdateChecker ?? GitHubAppUpdateChecker()
        let resolvedClaudeCredentialsReader = claudeCredentialsReader ?? ClaudeKeychainReader()

        let resolvedStore: (any SnapshotStoring)?
        var initialPersistenceError: String?
        if let store {
            resolvedStore = store
        } else {
            do {
                resolvedStore = try SnapshotStore()
            } catch {
                logger.error("Failed to create SnapshotStore: \(error)")
                resolvedStore = nil
                initialPersistenceError = error.localizedDescription
            }
        }
        let stateCoordinator = UsageStateCoordinator(
            store: resolvedStore,
            notificationManager: notificationManager
        )
        self.stateCoordinator = stateCoordinator
        self.presentationRuntime = AppPresentationRuntime()
        self.accountSessionStateRuntime = AccountSessionStateRuntime()
        self.sideEffectsRuntime = AppStateSideEffectsRuntime(
            store: resolvedStore,
            notificationManager: notificationManager
        )
        self.startupRuntime = AppStartupRuntime(
            stateCoordinator: stateCoordinator,
            notificationManager: notificationManager,
            store: resolvedStore
        )
        self.claudeSessionRuntime = ClaudeSessionRuntime(
            pipeline: claudeUsagePipeline,
            credentialsReader: resolvedClaudeCredentialsReader,
            cookieStore: claudeSessionCookieStore,
            webSessionController: claudeWebSessionController
        )
        let refreshCoordinator = UsageRefreshCoordinator(
            usageProvider: usageProvider,
            claudeUsageProvider: self.claudeUsageProvider,
            claudeUsagePipeline: claudeUsagePipeline,
            runningChecker: runningChecker,
            stateCoordinator: stateCoordinator,
            vault: self.vault,
            claudeCredentialsReader: resolvedClaudeCredentialsReader,
            claudeWebSessionController: claudeWebSessionController
        )
        self.refreshEngine = RefreshEngine(
            refreshCoordinator: refreshCoordinator,
            notificationManager: notificationManager,
            store: resolvedStore
        )

        let startup = startupRuntime.bootstrap()
        accounts = startup.accounts
        snapshots = startup.snapshots
        accountMetadata = startup.accountMetadata
        settings = settingsCoordinator.sanitized(startup.settings)
        if let details = startup.persistenceErrorDetails ?? initialPersistenceError {
            persistenceErrorMessage = storageErrorMessage(for: details)
        }
        claudeCookieConfigured = claudeSessionRuntime.isCookieConfigured
        applyPresentation()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemLocaleDidChange),
            name: NSLocale.currentLocaleDidChangeNotification,
            object: nil
        )
        if shouldStartPolling {
            startPolling()
        }
        if claudeSessionRuntime.isAvailable && !shouldStartPolling {
            Task { await refreshClaudeWebSessionStatus() }
        }
        Task { await refreshAppUpdateAvailability() }
    }

    deinit {
        timerTask?.cancel()
        NotificationCenter.default.removeObserver(self, name: NSLocale.currentLocaleDidChangeNotification, object: nil)
    }

    @objc private func systemLocaleDidChange() {
        objectWillChange.send()
    }

    func refreshNowAsync() async {
        await runRefresh()
    }

    func resetAllData() {
        sideEffectsRuntime.cancelNotifications(for: accounts)
        do {
            let projection = try stateCoordinator.resetAll()
            accounts = projection.accounts
            snapshots = projection.snapshots
            applyPresentation()
            accountMetadata = []
            settings = .default
            persistenceErrorMessage = nil
        } catch {
            logger.error("Failed to reset store: \(error)")
            presentPersistenceError(error)
        }
    }

    func deleteAccount(_ account: Account) {
        sideEffectsRuntime.cancelRenewalReminders(for: [account])

        do {
            let projection = try stateCoordinator.deleteAccount(
                account,
                from: currentPersistedState
            )
            accounts = projection.accounts
            snapshots = projection.snapshots
            accountMetadata.removeAll { $0.accountId == account.id }
            applyPresentation()
            persistenceErrorMessage = nil
        } catch {
            logger.error("Failed to delete account from store: \(error)")
            presentPersistenceError(error)
        }
    }

    func metadata(for accountId: UUID) -> AccountMetadata {
        accountMetadata.first(where: { $0.accountId == accountId }) ?? AccountMetadata(accountId: accountId)
    }

    func updatePriority(_ priority: AccountPriority, for accountId: UUID) {
        upsertMetadata(for: accountId) { metadata in
            metadata.priority = priority
        }
    }

    func updateNote(_ note: String, for accountId: UUID) {
        upsertMetadata(for: accountId) { metadata in
            metadata.note = note
        }
    }

    func updateAccountEmail(_ email: String, for accountId: UUID) {
        guard let idx = accounts.firstIndex(where: { $0.id == accountId }) else { return }
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        accounts[idx].email = trimmed.isEmpty ? nil : trimmed
        persistCurrentState()
    }

    func updatePollingInterval(_ interval: Double, codexRunning: Bool) {
        var updated = settings
        if codexRunning {
            updated.pollingWhenRunning = interval
        } else {
            updated.pollingWhenClosed = interval
        }
        applySettings(updated)
    }

    func resetPollingToDefaults() {
        var updated = settings
        updated.pollingWhenRunning = nil
        updated.pollingWhenClosed = nil
        applySettings(updated)
    }

    func setLanguage(_ language: AppLanguage) {
        var updated = settings
        updated.language = language
        applySettings(updated)
    }

    @discardableResult
    func saveClaudeSessionCookie(_ rawValue: String) -> Bool {
        let projection = claudeSessionRuntime.saveCookie(rawValue)
        claudeCookieConfigured = projection.isConfigured
        claudeCookieErrorMessage = projection.errorMessage
        if projection.shouldRefreshUsage {
            Task { await runRefresh() }
        }
        if let errorMessage = projection.errorMessage {
            logger.error("Failed to save Claude session cookie: \(errorMessage)")
        }
        return projection.errorMessage == nil
    }

    func clearClaudeSessionCookie() {
        let projection = claudeSessionRuntime.clearCookie()
        claudeCookieConfigured = projection.isConfigured
        claudeCookieErrorMessage = projection.errorMessage
        if projection.shouldRefreshUsage {
            Task { await runRefresh() }
        }
        if let errorMessage = projection.errorMessage {
            logger.error("Failed to clear Claude session cookie: \(errorMessage)")
        }
    }

    var claudeWebSessionAvailable: Bool {
        claudeSessionRuntime.isAvailable
    }

    var claudeWebLoginWebView: WKWebView? {
        claudeSessionRuntime.webView
    }

    func prepareClaudeWebLogin() {
        claudeSessionRuntime.prepareLoginPage()
    }

    func finalizeClaudeWebLogin() {
        Task {
            await refreshClaudeWebSessionStatus()
            await runRefresh()
        }
    }

    func clearClaudeWebSession() {
        Task {
            let projection = await claudeSessionRuntime.clearWebSession()
            if projection.didClearSession {
                claudeWebSessionConnected = false
                claudeWebSessionErrorMessage = nil
                await runRefresh()
            } else if let errorMessage = projection.errorMessage {
                logger.error("Failed to clear Claude web session: \(errorMessage)")
                claudeWebSessionErrorMessage = errorMessage
            }
        }
    }

    func refreshClaudeWebSessionStatus() async {
        guard claudeSessionRuntime.isAvailable else { return }
        if let projection = await claudeSessionRuntime.refreshWebSessionStatus() {
            applyClaudeWebSessionStatus(projection)
        } else {
            claudeWebSessionConnected = false
            claudeWebSessionErrorMessage = nil
        }
    }

    func setCooldownNotificationsEnabled(_ isEnabled: Bool) {
        var updated = settings
        updated.cooldownNotificationsEnabled = isEnabled
        applySettings(updated)
        sideEffectsRuntime.reconcileCooldownNotifications(in: currentPersistedState)
    }

    func setRenewalReminderEnabled(
        _ isEnabled: Bool,
        keyPath: WritableKeyPath<RenewalReminderSettings, Bool>
    ) {
        var updated = settings
        updated.renewalReminders[keyPath: keyPath] = isEnabled
        applySettings(updated)
        sideEffectsRuntime.reconcileRenewalReminders(in: currentPersistedState)
    }

    func snapshot(for accountId: UUID) -> UsageSnapshot? {
        snapshots.last(where: { $0.accountId == accountId })
    }

    func canSwitch(to account: Account) -> Bool {
        accountSessionStateRuntime.canSwitch(
            to: account,
            switchingAccountId: switchingAccountId,
            activeCodexEmail: activeCodexEmail,
            vault: vault
        )
    }

    func isActiveAccount(_ account: Account) -> Bool {
        accountSessionStateRuntime.isActiveAccount(
            account,
            activeCodexEmail: activeCodexEmail,
            activeClaudeAccountIdentifier: activeClaudeAccountIdentifier
        )
    }

    func switchToAccount(_ account: Account) {
        Task { await switchToAccountAsync(account) }
    }

    func openAvailableUpdate() {
        guard let availableUpdate else { return }
        NSWorkspace.shared.open(availableUpdate.downloadURL)
    }

    func dismissAvailableUpdate() {
        guard let availableUpdate else { return }
        var updatedSettings = settings
        updatedSettings.dismissedUpdateVersion = availableUpdate.version
        settings = settingsCoordinator.sanitized(updatedSettings)
        self.availableUpdate = nil
        persistCurrentState()
    }

    func switchToAccountAsync(_ account: Account) async {
        switchingAccountId = account.id
        switchErrorMessage = nil
        guard let projection = await accountSwitchRuntime.switchAccount(
            account,
            currentSwitchingAccountId: nil
        ) else {
            switchingAccountId = nil
            return
        }

        if let confirmedEmail = projection.confirmedEmail {
            activeCodexEmail = confirmedEmail
        }
        if let errorMessage = projection.errorMessage {
            logger.error("Failed to switch to account: \(errorMessage)")
            switchErrorMessage = errorMessage
        }
        switchingAccountId = projection.switchingAccountId
        if projection.shouldRefresh {
            await runRefresh()
        }
    }

    var sortedAccounts: [Account] {
        presentationRuntime.sortAccounts(
            accounts: accounts,
            accountMetadata: accountMetadata,
            snapshots: snapshots
        )
    }

    private func startPolling() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.runRefresh()
                let interval = self.pollingCoordinator.interval(
                    codexRunning: self.codexRunning,
                    settings: self.settings
                )
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    private func runRefresh() async {
        if let refreshTask {
            await refreshTask.value
            return
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.refreshTask = nil }
            await self.performRefresh()
        }
        refreshTask = task
        await task.value
    }

    private func performRefresh() async {
        lastRefreshAt = Date()
        let result = await refreshEngine.refresh(
            from: currentPersistedState,
            language: resolvedLanguage
        )
        codexRunning = result.codexRunning
        activeCodexEmail = result.activeCodexEmail
        activeClaudeAccountIdentifier = result.activeClaudeAccountIdentifier
        accounts = result.accounts
        snapshots = result.snapshots
        if let details = result.persistenceErrorDetails {
            persistenceErrorMessage = storageErrorMessage(for: details)
        } else {
            persistenceErrorMessage = nil
        }
        if let claudeWebSessionStatus = result.claudeWebSessionStatus {
            applyClaudeWebSessionStatus(claudeWebSessionStatus)
        }
        compactLabel = result.compactLabel
        menuBarState = result.menuBarState
        await refreshAppUpdateAvailability()
    }

    private func applyClaudeWebSessionStatus(_ projection: ClaudeWebSessionStatusProjection) {
        claudeWebSessionConnected = projection.isConnected
        claudeWebSessionErrorMessage = projection.errorMessage
    }

    private func refreshAppUpdateAvailability() async {
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        guard let update = await appUpdateChecker.checkForUpdate(currentVersion: currentVersion) else {
            availableUpdate = nil
            return
        }

        let dismissedVersion = settings.dismissedUpdateVersion.map(GitHubAppUpdateChecker.normalizedVersion)
        let availableVersion = GitHubAppUpdateChecker.normalizedVersion(update.version)
        availableUpdate = dismissedVersion == availableVersion ? nil : update
    }

    private var currentPersistedState: PersistedState {
        PersistedState(
            accounts: accounts,
            snapshots: snapshots,
            accountMetadata: accountMetadata,
            settings: settings
        )
    }

    private func applySettings(_ newSettings: AppSettingsState) {
        settings = settingsCoordinator.sanitized(newSettings)
        applyPresentation()
        persistCurrentState()
    }

    private func applyPresentation(now: Date = .now) {
        let projection = presentationRuntime.makeMenuBarPresentation(
            accounts: accounts,
            snapshots: snapshots,
            language: resolvedLanguage,
            now: now
        )
        compactLabel = projection.compactLabel
        menuBarState = projection.menuBarState
    }

    private func persistCurrentState() {
        do {
            try sideEffectsRuntime.persist(currentPersistedState)
            persistenceErrorMessage = nil
        } catch {
            logger.error("Failed to persist state: \(error)")
            presentPersistenceError(error)
        }
    }

    private func storageErrorMessage(for details: String) -> String {
        strings.localStorageError(details)
    }

    private func presentPersistenceError(_ error: any Error) {
        persistenceErrorMessage = storageErrorMessage(for: error.localizedDescription)
    }

    private func upsertMetadata(for accountId: UUID, update: (inout AccountMetadata) -> Void) {
        if let index = accountMetadata.firstIndex(where: { $0.accountId == accountId }) {
            update(&accountMetadata[index])
        } else {
            var metadata = AccountMetadata(accountId: accountId)
            update(&metadata)
            accountMetadata.append(metadata)
        }
        persistCurrentState()
    }
}
