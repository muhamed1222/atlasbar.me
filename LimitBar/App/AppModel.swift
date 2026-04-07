import Foundation
import AppKit
import OSLog
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

    var resolvedLanguage: ResolvedAppLanguage {
        settings.language.resolved()
    }

    var strings: AppStrings {
        AppStrings(language: resolvedLanguage)
    }

    var appLocale: Locale {
        resolvedLanguage.locale
    }

    private let usageProvider: any CurrentUsageProviding
    private let claudeUsageProvider: (any CurrentUsageProviding)?
    private let claudeUsagePipeline: (any ClaudeUsagePipelining)?
    private let runningChecker: any CodexRunningChecking
    private let pollingCoordinator: PollingCoordinator
    private let stateCoordinator: UsageStateCoordinator
    private let refreshCoordinator: UsageRefreshCoordinator
    private let notificationManager: any NotificationScheduling
    private let renewalReminderScheduler = RenewalReminderScheduler()
    private let dailyResetRecoveryCoordinator = DailyResetRecoveryCoordinator()
    private let store: (any SnapshotStoring)?
    private let settingsCoordinator = SettingsCoordinator()
    private let vault: any AccountVaulting
    private let sessionSwitcher: any CodexSessionSwitching
    private let claudeCredentialsReader: any ClaudeCredentialsReading
    private let claudeSessionCookieStore: (any ClaudeSessionCookieStoring)?
    private let claudeWebSessionController: (any ClaudeWebSessionControlling)?
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
        shouldStartPolling: Bool = AppRuntimeDefaults.shouldStartPolling
    ) {
        self.usageProvider = usageProvider
        self.claudeUsageProvider = claudeUsageProvider ?? claudeUsagePipeline
        self.claudeUsagePipeline = claudeUsagePipeline
        self.runningChecker = runningChecker
        self.pollingCoordinator = pollingCoordinator
        self.notificationManager = notificationManager
        self.vault = vault ?? AccountVault()
        self.sessionSwitcher = sessionSwitcher ?? CodexSessionSwitcher(vault: self.vault)
        self.claudeCredentialsReader = claudeCredentialsReader ?? ClaudeKeychainReader()
        self.claudeSessionCookieStore = claudeSessionCookieStore
        self.claudeWebSessionController = claudeWebSessionController

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
        self.store = resolvedStore
        let stateCoordinator = UsageStateCoordinator(
            store: resolvedStore,
            notificationManager: notificationManager
        )
        self.stateCoordinator = stateCoordinator
        self.refreshCoordinator = UsageRefreshCoordinator(
            usageProvider: usageProvider,
            claudeUsageProvider: self.claudeUsageProvider,
            claudeUsagePipeline: claudeUsagePipeline,
            runningChecker: runningChecker,
            stateCoordinator: stateCoordinator,
            vault: self.vault,
            claudeCredentialsReader: self.claudeCredentialsReader,
            claudeWebSessionController: claudeWebSessionController
        )

        let loadResult = stateCoordinator.loadInitialState()
        let state = loadResult.state
        accounts = state.accounts
        snapshots = state.snapshots
        accountMetadata = deduplicatedMetadata(state.accountMetadata, for: state.accounts)
        settings = settingsCoordinator.sanitized(state.settings)
        if let details = loadResult.persistenceError ?? initialPersistenceError {
            persistenceErrorMessage = storageErrorMessage(for: details)
        }
        claudeCookieConfigured = claudeSessionCookieStore?.hasStoredCookie() ?? false
        reconcilePredictedDailyResets()
        refreshCompactLabel()
        reconcilePersistedNotifications()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemLocaleDidChange),
            name: NSLocale.currentLocaleDidChangeNotification,
            object: nil
        )
        if shouldStartPolling {
            startPolling()
        }
        if claudeWebSessionController != nil {
            Task { await refreshClaudeWebSessionStatus() }
        }
    }

    deinit {
        timerTask?.cancel()
        NotificationCenter.default.removeObserver(self, name: NSLocale.currentLocaleDidChangeNotification, object: nil)
    }

    @objc private func systemLocaleDidChange() {
        objectWillChange.send()
    }

    func refreshNow() {
        Task { await refreshNowAsync() }
    }

    func refreshNowAsync() async {
        await runRefresh()
    }

    func openCodex() {
        let bundleIds = [
            "com.openai.codex",
            "com.openai.Codex",
            "openai.codex",
            "com.todesktop.230313mzl4w4u92"
        ]
        for id in bundleIds {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                NSWorkspace.shared.openApplication(at: url, configuration: .init())
                return
            }
        }
        if let url = findAppByName("Codex") {
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        } else {
            logger.warning("Could not find Codex app to open")
        }
    }

    func resetAllData() {
        cancelNotifications(for: accounts)
        do {
            let projection = try stateCoordinator.resetAll()
            accounts = projection.accounts
            snapshots = projection.snapshots
            compactLabel = projection.compactLabel
            accountMetadata = []
            settings = .default
            persistenceErrorMessage = nil
        } catch {
            logger.error("Failed to reset store: \(error)")
            presentPersistenceError(error)
        }
    }

    func deleteAccount(_ account: Account) {
        notificationManager.cancelNotifications(
            withIdentifiers: renewalReminderScheduler.reminderIdentifiers(for: account.id)
        )

        do {
            let projection = try stateCoordinator.deleteAccount(
                account,
                from: currentPersistedState
            )
            accounts = projection.accounts
            snapshots = projection.snapshots
            refreshCompactLabel()
            accountMetadata.removeAll { $0.accountId == account.id }
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
        persist()
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
        guard let claudeSessionCookieStore else { return false }
        do {
            try claudeSessionCookieStore.saveCookie(rawValue)
            claudeCookieConfigured = claudeSessionCookieStore.hasStoredCookie()
            claudeCookieErrorMessage = nil
            Task { await runRefresh() }
            return true
        } catch {
            logger.error("Failed to save Claude session cookie: \(error)")
            claudeCookieErrorMessage = error.localizedDescription
            claudeCookieConfigured = claudeSessionCookieStore.hasStoredCookie()
            return false
        }
    }

    func clearClaudeSessionCookie() {
        guard let claudeSessionCookieStore else { return }
        do {
            try claudeSessionCookieStore.clearCookie()
            claudeCookieConfigured = false
            claudeCookieErrorMessage = nil
            Task { await runRefresh() }
        } catch {
            logger.error("Failed to clear Claude session cookie: \(error)")
            claudeCookieErrorMessage = error.localizedDescription
            claudeCookieConfigured = claudeSessionCookieStore.hasStoredCookie()
        }
    }

    var claudeWebSessionAvailable: Bool {
        claudeWebSessionController != nil
    }

    var claudeWebLoginWebView: WKWebView? {
        claudeWebSessionController?.webView
    }

    func prepareClaudeWebLogin() {
        claudeWebSessionController?.prepareLoginPage()
    }

    func finalizeClaudeWebLogin() {
        Task {
            await refreshClaudeWebSessionStatus()
            await runRefresh()
        }
    }

    func clearClaudeWebSession() {
        guard let claudeWebSessionController else { return }
        Task {
            do {
                try await claudeWebSessionController.clearSession()
                claudeWebSessionConnected = false
                claudeWebSessionErrorMessage = nil
                await runRefresh()
            } catch {
                logger.error("Failed to clear Claude web session: \(error)")
                claudeWebSessionErrorMessage = error.localizedDescription
            }
        }
    }

    func refreshClaudeWebSessionStatus() async {
        if let claudeUsagePipeline {
            if let projection = await claudeUsagePipeline.refreshWebSessionStatus() {
                applyClaudeWebSessionStatus(projection)
            } else {
                claudeWebSessionConnected = false
                claudeWebSessionErrorMessage = nil
            }
            return
        }

        guard let claudeWebSessionController else { return }
        guard let requestedOrganizationUUID = claudeCredentialsReader.readCredentials()?.organizationUUID else {
            claudeWebSessionConnected = false
            claudeWebSessionErrorMessage = nil
            return
        }

        let result = await claudeWebSessionController.fetchUsageResponse(
            organizationUUID: requestedOrganizationUUID
        )
        let currentOrganizationUUID = claudeCredentialsReader.readCredentials()?.organizationUUID

        guard currentOrganizationUUID == requestedOrganizationUUID else {
            guard let currentOrganizationUUID else {
                claudeWebSessionConnected = false
                claudeWebSessionErrorMessage = nil
                return
            }

            applyClaudeWebSessionStatus(
                ClaudeWebSessionStatusProjection.evaluate(
                    result: claudeWebSessionController.cachedUsageResponse(
                        organizationUUID: currentOrganizationUUID
                    ),
                    expectedOrganizationUUID: currentOrganizationUUID
                )
            )
            return
        }

        applyClaudeWebSessionStatus(
            ClaudeWebSessionStatusProjection.evaluate(
                result: result,
                expectedOrganizationUUID: requestedOrganizationUUID
            )
        )
    }

    func setCooldownNotificationsEnabled(_ isEnabled: Bool) {
        var updated = settings
        updated.cooldownNotificationsEnabled = isEnabled
        applySettings(updated)

        for account in accounts {
            if let snapshot = snapshot(for: account.id) {
                scheduleNotificationIfNeeded(snapshot: snapshot, accountId: account.id)
            } else {
                notificationManager.cancelCooldownReadyNotification(
                    accountId: account.id,
                    accountName: account.displayName
                )
            }
        }
    }

    func setRenewalReminderEnabled(
        _ isEnabled: Bool,
        keyPath: WritableKeyPath<RenewalReminderSettings, Bool>
    ) {
        var updated = settings
        updated.renewalReminders[keyPath: keyPath] = isEnabled
        applySettings(updated)

        for account in accounts {
            reconcileRenewalReminders(for: account.id)
        }
    }

    func snapshot(for accountId: UUID) -> UsageSnapshot? {
        snapshots.last(where: { $0.accountId == accountId })
    }

    func canSwitch(to account: Account) -> Bool {
        guard switchingAccountId == nil else { return false }
        guard account.provider.caseInsensitiveCompare(Provider.codex.name) == .orderedSame else { return false }
        guard let email = account.email else { return false }
        guard email != activeCodexEmail else { return false }
        return vault.hasSavedAuth(for: email)
    }

    func isActiveAccount(_ account: Account) -> Bool {
        if account.provider.caseInsensitiveCompare(Provider.codex.name) == .orderedSame {
            guard let email = account.email, let activeCodexEmail else {
                return false
            }
            return email.caseInsensitiveCompare(activeCodexEmail) == .orderedSame
        }

        if account.provider.caseInsensitiveCompare(Provider.claude.name) == .orderedSame {
            guard let activeClaudeAccountIdentifier else {
                return false
            }
            let activeIdentifier = activeClaudeAccountIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !activeIdentifier.isEmpty else { return false }

            if let email = account.email,
               email.caseInsensitiveCompare(activeIdentifier) == .orderedSame {
                return true
            }

            if let label = account.label,
               label.caseInsensitiveCompare(activeIdentifier) == .orderedSame {
                return true
            }

            return false
        }

        return false
    }

    func switchToAccount(_ account: Account) {
        Task { await switchToAccountAsync(account) }
    }

    func switchToAccountAsync(_ account: Account) async {
        guard switchingAccountId == nil else { return }
        guard account.provider.caseInsensitiveCompare(Provider.codex.name) == .orderedSame else { return }
        guard let email = account.email else { return }
        switchingAccountId = account.id
        switchErrorMessage = nil
        do {
            let confirmedEmail = try await sessionSwitcher.switchTo(email: email)
            activeCodexEmail = confirmedEmail
            await runRefresh()
        } catch {
            logger.error("Failed to switch to account: \(error)")
            switchErrorMessage = error.localizedDescription
        }
        switchingAccountId = nil
    }

    var sortedAccounts: [Account] {
        accounts.sorted { lhs, rhs in
            let lhsMetadata = metadata(for: lhs.id)
            let rhsMetadata = metadata(for: rhs.id)
            if lhsMetadata.priority.sortWeight != rhsMetadata.priority.sortWeight {
                return lhsMetadata.priority.sortWeight < rhsMetadata.priority.sortWeight
            }

            let lhsLastSynced = snapshot(for: lhs.id)?.lastSyncedAt ?? .distantPast
            let rhsLastSynced = snapshot(for: rhs.id)?.lastSyncedAt ?? .distantPast
            if lhsLastSynced != rhsLastSynced {
                return lhsLastSynced > rhsLastSynced
            }

            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
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
        let outcome = await refreshCoordinator.refresh(from: currentPersistedState)
        codexRunning = outcome.codexRunning
        activeCodexEmail = outcome.activeCodexEmail
        activeClaudeAccountIdentifier = outcome.activeClaudeAccountIdentifier
        accounts = outcome.accounts
        snapshots = outcome.snapshots
        if let details = outcome.persistenceErrorDetails {
            persistenceErrorMessage = storageErrorMessage(for: details)
        } else {
            persistenceErrorMessage = nil
        }
        if outcome.shouldReconcileRenewalNotifications {
            for account in accounts {
                reconcileRenewalReminders(for: account.id)
            }
        }
        if outcome.shouldReconcileCooldownNotifications {
            reconcileCooldownNotifications()
        }
        if let claudeWebSessionStatus = outcome.claudeWebSessionStatus {
            applyClaudeWebSessionStatus(claudeWebSessionStatus)
        }
        reconcilePredictedDailyResets()
        refreshCompactLabel()
    }

    private func applyClaudeWebSessionStatus(_ projection: ClaudeWebSessionStatusProjection) {
        claudeWebSessionConnected = projection.isConnected
        claudeWebSessionErrorMessage = projection.errorMessage
    }

    private var currentPersistedState: PersistedState {
        PersistedState(
            accounts: accounts,
            snapshots: snapshots,
            accountMetadata: accountMetadata,
            settings: settings
        )
    }

    private func deduplicatedMetadata(
        _ metadata: [AccountMetadata],
        for accounts: [Account]
    ) -> [AccountMetadata] {
        let validIds = Set(accounts.map(\.id))
        var seen = Set<UUID>()
        return metadata.filter { item in
            guard validIds.contains(item.accountId), !seen.contains(item.accountId) else {
                return false
            }
            seen.insert(item.accountId)
            return true
        }
    }

    private func applySettings(_ newSettings: AppSettingsState) {
        settings = settingsCoordinator.sanitized(newSettings)
        refreshCompactLabel()
        persist()
    }

    private func refreshCompactLabel() {
        guard !accounts.isEmpty else {
            compactLabel = "--"
            menuBarState = .noData
            return
        }

        let liveSnapshots = snapshots.filter { $0.usageStatus != .stale && $0.usageStatus != .unknown }
        guard !liveSnapshots.isEmpty else {
            let nextReset = snapshots
                .filter { shouldScheduleResetReadyNotification(snapshot: $0) }
                .compactMap(\.nextResetAt)
                .min()
            if let nextReset {
                compactLabel = countdownString(until: nextReset, language: resolvedLanguage)
                menuBarState = .allCoolingDown(nextResetAt: nextReset)
            } else {
                compactLabel = staleUsageLabel(hasSnapshots: !snapshots.isEmpty, language: resolvedLanguage)
                menuBarState = .noData
            }
            return
        }

        let available = liveSnapshots.filter { $0.usageStatus == .available }
        let waitingForReset = liveSnapshots.filter { shouldScheduleResetReadyNotification(snapshot: $0) }

        if available.isEmpty {
            // Nothing available — show countdown to soonest reset
            let nextReset = waitingForReset.compactMap(\.nextResetAt).min()
            menuBarState = .allCoolingDown(nextResetAt: nextReset)
            if let nextReset {
                compactLabel = countdownString(until: nextReset, language: resolvedLanguage)
            } else {
                compactLabel = "~"
            }
            return
        }

        // Pick the best available Codex snapshot (most session remaining), fall back to any available
        let bestSnapshot: UsageSnapshot = available
            .filter { $0.sessionPercentUsed != nil }
            .max(by: {
                remainingPercent(from: $0.sessionPercentUsed ?? 100) <
                remainingPercent(from: $1.sessionPercentUsed ?? 100)
            }) ?? available.max(by: {
                ($0.lastSyncedAt ?? .distantPast) < ($1.lastSyncedAt ?? .distantPast)
            }) ?? available[0]

        compactLabel = shortUsageLabel(snapshot: bestSnapshot, language: resolvedLanguage)

        // Determine green vs yellow: any account with >30% session remaining = green
        let hasGoodHeadroom = available.contains {
            guard let session = $0.sessionPercentUsed else { return true }
            return remainingPercent(from: session) > 30
        }
        menuBarState = hasGoodHeadroom ? .available : .low
    }

    private func persist() {
        do {
            try store?.save(currentPersistedState)
            persistenceErrorMessage = nil
        } catch {
            logger.error("Failed to persist state: \(error)")
            presentPersistenceError(error)
        }
    }

    private func scheduleNotificationIfNeeded(snapshot: UsageSnapshot, accountId: UUID) {
        guard let account = accounts.first(where: { $0.id == accountId }) else {
            return
        }

        guard settings.cooldownNotificationsEnabled else {
            notificationManager.cancelCooldownReadyNotification(
                accountId: account.id,
                accountName: account.displayName
            )
            return
        }

        guard shouldScheduleResetReadyNotification(snapshot: snapshot),
              let nextResetAt = snapshot.nextResetAt else {
            notificationManager.cancelCooldownReadyNotification(
                accountId: account.id,
                accountName: account.displayName
            )
            return
        }

        notificationManager.scheduleCooldownReadyNotification(
            accountId: account.id,
            accountName: account.displayName,
            at: nextResetAt
        )
    }

    private func reconcileCooldownNotifications() {
        for account in accounts {
            if let snapshot = snapshot(for: account.id) {
                scheduleNotificationIfNeeded(snapshot: snapshot, accountId: account.id)
            } else {
                notificationManager.cancelCooldownReadyNotification(
                    accountId: account.id,
                    accountName: account.displayName
                )
            }
        }
    }

    private func reconcileRenewalReminders(for accountId: UUID) {
        guard let account = accounts.first(where: { $0.id == accountId }) else {
            return
        }
        renewalReminderScheduler.reconcile(
            account: account,
            snapshot: snapshot(for: accountId),
            settings: settings,
            notificationManager: notificationManager
        )
    }

    private func reconcilePersistedNotifications() {
        reconcileCooldownNotifications()
        for account in accounts {
            reconcileRenewalReminders(for: account.id)
        }
    }

    private func reconcilePredictedDailyResets(now: Date = .now) {
        let outcome = dailyResetRecoveryCoordinator.reconcile(
            snapshots: snapshots,
            now: now
        )

        guard !outcome.recoveredAccountIDs.isEmpty else {
            return
        }

        snapshots = outcome.snapshots
        persist()
        reconcileCooldownNotifications()
    }

    private func cancelNotifications(for accounts: [Account]) {
        for account in accounts {
            notificationManager.cancelCooldownReadyNotification(
                accountId: account.id,
                accountName: account.displayName
            )
            notificationManager.cancelNotifications(
                withIdentifiers: renewalReminderScheduler.reminderIdentifiers(for: account.id)
            )
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
            accountMetadata[index].updatedAt = .now
        } else {
            var metadata = AccountMetadata(accountId: accountId)
            update(&metadata)
            metadata.updatedAt = .now
            accountMetadata.append(metadata)
        }
        persist()
    }

    private func findAppByName(_ name: String) -> URL? {
        let paths = ["/Applications/\(name).app", "\(NSHomeDirectory())/Applications/\(name).app"]
        return paths.compactMap { URL(fileURLWithPath: $0) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }
}
