import Foundation

struct AppStartupProjection: Equatable {
    var accounts: [Account]
    var snapshots: [UsageSnapshot]
    var accountMetadata: [AccountMetadata]
    var settings: AppSettingsState
    var persistenceErrorDetails: String?
}

struct AppStartupRuntime: Sendable {
    private let stateCoordinator: UsageStateCoordinator
    private let settingsCoordinator: SettingsCoordinator
    private let dailyResetRecoveryCoordinator: DailyResetRecoveryCoordinator
    private let sideEffectsRuntime: AppStateSideEffectsRuntime

    init(
        stateCoordinator: UsageStateCoordinator,
        notificationManager: any NotificationScheduling,
        store: (any SnapshotStoring)?,
        settingsCoordinator: SettingsCoordinator = SettingsCoordinator(),
        renewalReminderScheduler: RenewalReminderScheduler = RenewalReminderScheduler(),
        dailyResetRecoveryCoordinator: DailyResetRecoveryCoordinator = DailyResetRecoveryCoordinator()
    ) {
        self.stateCoordinator = stateCoordinator
        self.settingsCoordinator = settingsCoordinator
        self.dailyResetRecoveryCoordinator = dailyResetRecoveryCoordinator
        self.sideEffectsRuntime = AppStateSideEffectsRuntime(
            store: store,
            notificationManager: notificationManager,
            renewalReminderScheduler: renewalReminderScheduler
        )
    }

    func bootstrap(now: Date = .now) -> AppStartupProjection {
        let loadResult = stateCoordinator.loadInitialState()
        var state = loadResult.state
        var persistenceErrorDetails = loadResult.persistenceError

        let recovery = dailyResetRecoveryCoordinator.reconcile(
            snapshots: state.snapshots,
            now: now
        )
        if !recovery.recoveredAccountIDs.isEmpty {
            state.snapshots = recovery.snapshots
            do {
                try sideEffectsRuntime.persist(state)
            } catch {
                persistenceErrorDetails = mergedPersistenceErrorDetails(
                    existing: persistenceErrorDetails,
                    newDetails: error.localizedDescription
                )
            }
        }

        let accountMetadata = deduplicatedMetadata(
            state.accountMetadata,
            for: state.accounts
        )
        let projectedState = PersistedState(
            accounts: state.accounts,
            snapshots: state.snapshots,
            accountMetadata: accountMetadata,
            settings: settingsCoordinator.sanitized(state.settings)
        )

        sideEffectsRuntime.reconcileNotifications(in: projectedState, now: now)

        return AppStartupProjection(
            accounts: projectedState.accounts,
            snapshots: projectedState.snapshots,
            accountMetadata: projectedState.accountMetadata,
            settings: projectedState.settings,
            persistenceErrorDetails: persistenceErrorDetails
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

    private func mergedPersistenceErrorDetails(
        existing: String?,
        newDetails: String
    ) -> String {
        guard let existing, !existing.isEmpty else {
            return newDetails
        }
        return existing + "\n" + newDetails
    }
}
