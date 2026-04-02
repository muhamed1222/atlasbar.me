import Foundation
import AppKit
import OSLog

private let logger = Logger(subsystem: "me.atlasbar.LimitBar", category: "AppModel")

private enum AppRuntimeDefaults {
    static var shouldStartPolling: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var compactLabel: String = "--"
    @Published var codexRunning: Bool = false
    @Published var lastRefreshAt: Date?
    @Published var accounts: [Account] = []
    @Published var snapshots: [UsageSnapshot] = []
    @Published var accountMetadata: [AccountMetadata] = []
    @Published var settings: AppSettingsState = .default

    private let usageProvider: any CurrentUsageProviding
    private let runningChecker: any CodexRunningChecking
    private let pollingCoordinator: PollingCoordinator
    private let stateCoordinator: UsageStateCoordinator
    private let notificationManager: any NotificationScheduling
    private let renewalReminderScheduler = RenewalReminderScheduler()
    private let store: (any SnapshotStoring)?
    private let settingsCoordinator = SettingsCoordinator()
    private var timerTask: Task<Void, Never>?

    init(
        usageProvider: any CurrentUsageProviding = APIBasedUsageProvider(),
        runningChecker: any CodexRunningChecking = ProcessWatcher(),
        pollingCoordinator: PollingCoordinator = PollingCoordinator(),
        notificationManager: any NotificationScheduling = NotificationManager(),
        store: (any SnapshotStoring)? = nil,
        shouldStartPolling: Bool = AppRuntimeDefaults.shouldStartPolling
    ) {
        self.usageProvider = usageProvider
        self.runningChecker = runningChecker
        self.pollingCoordinator = pollingCoordinator
        self.notificationManager = notificationManager

        let resolvedStore: (any SnapshotStoring)?
        if let store {
            resolvedStore = store
        } else {
            do {
                resolvedStore = try SnapshotStore()
            } catch {
                logger.error("Failed to create SnapshotStore: \(error)")
                resolvedStore = nil
            }
        }
        self.store = resolvedStore
        self.stateCoordinator = UsageStateCoordinator(
            store: resolvedStore,
            notificationManager: notificationManager
        )

        let state = stateCoordinator.loadInitialState()
        accounts = state.accounts
        snapshots = state.snapshots
        accountMetadata = deduplicatedMetadata(state.accountMetadata, for: state.accounts)
        settings = settingsCoordinator.sanitized(state.settings)
        reconcilePersistedNotifications()
        if shouldStartPolling {
            startPolling()
        }
    }

    deinit {
        timerTask?.cancel()
    }

    func refreshNow() {
        Task { await refreshNowAsync() }
    }

    func refreshNowAsync() async {
        await performRefresh()
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
        } catch {
            logger.error("Failed to reset store: \(error)")
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
            compactLabel = projection.compactLabel
            accountMetadata.removeAll { $0.accountId == account.id }
        } catch {
            logger.error("Failed to delete account from store: \(error)")
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

    func updatePollingInterval(_ interval: Double, codexRunning: Bool) {
        var updated = settings
        if codexRunning {
            updated.pollingWhenRunning = interval
        } else {
            updated.pollingWhenClosed = interval
        }
        applySettings(updated)
    }

    func setCooldownNotificationsEnabled(_ isEnabled: Bool) {
        var updated = settings
        updated.cooldownNotificationsEnabled = isEnabled
        applySettings(updated)

        for account in accounts {
            if let snapshot = snapshot(for: account.id) {
                scheduleNotificationIfNeeded(snapshot: snapshot, accountId: account.id)
            } else {
                notificationManager.cancelCooldownReadyNotification(accountName: account.displayName)
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
                await self.performRefresh()
                let interval = self.pollingCoordinator.interval(
                    codexRunning: self.codexRunning,
                    settings: self.settings
                )
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    private func performRefresh() async {
        lastRefreshAt = Date()
        codexRunning = runningChecker.isCodexRunning

        guard let currentUsage = await usageProvider.fetchCurrentUsage() else {
            do {
                let projection = try stateCoordinator.markStale(from: currentPersistedState)
                accounts = projection.accounts
                snapshots = projection.snapshots
                compactLabel = projection.compactLabel
            } catch {
                logger.error("Failed to mark usage state stale: \(error)")
                compactLabel = staleUsageLabel(hasSnapshots: !snapshots.isEmpty)
            }
            return
        }

        do {
            let projection = try stateCoordinator.applyRefresh(
                currentUsage,
                to: currentPersistedState
            )
            accounts = projection.accounts
            snapshots = projection.snapshots
            compactLabel = projection.compactLabel
            if let accountId = mostRecentlySyncedAccountId() {
                reconcileRenewalReminders(for: accountId)
            }
        } catch {
            logger.error("Failed to apply refreshed usage state: \(error)")
        }
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
        persist()
    }

    private func persist() {
        do {
            try store?.save(currentPersistedState)
        } catch {
            logger.error("Failed to persist state: \(error)")
        }
    }

    private func scheduleNotificationIfNeeded(snapshot: UsageSnapshot, accountId: UUID) {
        guard let account = accounts.first(where: { $0.id == accountId }) else {
            return
        }

        guard settings.cooldownNotificationsEnabled else {
            notificationManager.cancelCooldownReadyNotification(accountName: account.displayName)
            return
        }

        guard let nextResetAt = snapshot.nextResetAt else {
            notificationManager.cancelCooldownReadyNotification(accountName: account.displayName)
            return
        }

        notificationManager.scheduleCooldownReadyNotification(accountName: account.displayName, at: nextResetAt)
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
        for account in accounts {
            if let snapshot = snapshot(for: account.id) {
                scheduleNotificationIfNeeded(snapshot: snapshot, accountId: account.id)
            } else {
                notificationManager.cancelCooldownReadyNotification(accountName: account.displayName)
            }
            reconcileRenewalReminders(for: account.id)
        }
    }

    private func cancelNotifications(for accounts: [Account]) {
        for account in accounts {
            notificationManager.cancelCooldownReadyNotification(accountName: account.displayName)
            notificationManager.cancelNotifications(
                withIdentifiers: renewalReminderScheduler.reminderIdentifiers(for: account.id)
            )
        }
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

    private func mostRecentlySyncedAccountId() -> UUID? {
        snapshots.max { lhs, rhs in
            (lhs.lastSyncedAt ?? .distantPast) < (rhs.lastSyncedAt ?? .distantPast)
        }?.accountId
    }

    private func findAppByName(_ name: String) -> URL? {
        let paths = ["/Applications/\(name).app", "\(NSHomeDirectory())/Applications/\(name).app"]
        return paths.compactMap { URL(fileURLWithPath: $0) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }
}
