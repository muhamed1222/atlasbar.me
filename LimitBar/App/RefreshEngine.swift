import Foundation

struct RefreshEngineResult: Equatable {
    let codexRunning: Bool
    let activeCodexEmail: String?
    let activeClaudeAccountIdentifier: String?
    let accounts: [Account]
    let snapshots: [UsageSnapshot]
    let persistenceErrorDetails: String?
    let compactLabel: String
    let menuBarState: MenuBarState
    let claudeWebSessionStatus: ClaudeWebSessionStatusProjection?
}

struct RefreshEngine: Sendable {
    private let refreshCoordinator: any UsageRefreshing
    private let notificationManager: any NotificationScheduling
    private let store: (any SnapshotStoring)?
    private let renewalReminderScheduler: RenewalReminderScheduler
    private let dailyResetRecoveryCoordinator: DailyResetRecoveryCoordinator
    private let presentationRuntime: AppPresentationRuntime

    init(
        refreshCoordinator: any UsageRefreshing,
        notificationManager: any NotificationScheduling,
        store: (any SnapshotStoring)? = nil,
        renewalReminderScheduler: RenewalReminderScheduler = RenewalReminderScheduler(),
        dailyResetRecoveryCoordinator: DailyResetRecoveryCoordinator = DailyResetRecoveryCoordinator(),
        presentationRuntime: AppPresentationRuntime = AppPresentationRuntime()
    ) {
        self.refreshCoordinator = refreshCoordinator
        self.notificationManager = notificationManager
        self.store = store
        self.renewalReminderScheduler = renewalReminderScheduler
        self.dailyResetRecoveryCoordinator = dailyResetRecoveryCoordinator
        self.presentationRuntime = presentationRuntime
    }

    func refresh(
        from state: PersistedState,
        language: ResolvedAppLanguage,
        now: Date = .now
    ) async -> RefreshEngineResult {
        let outcome = await refreshCoordinator.refresh(from: state)
        let accounts = outcome.accounts

        var snapshots = outcome.snapshots
        var persistenceErrorDetails = outcome.persistenceErrorDetails

        let recovery = dailyResetRecoveryCoordinator.reconcile(snapshots: snapshots, now: now)
        snapshots = recovery.snapshots

        if !recovery.recoveredAccountIDs.isEmpty {
            do {
                try store?.save(
                    PersistedState(
                        accounts: accounts,
                        snapshots: snapshots,
                        accountMetadata: state.accountMetadata,
                        settings: state.settings
                    )
                )
            } catch {
                persistenceErrorDetails = mergedErrorDetails(
                    existing: persistenceErrorDetails,
                    appended: error.localizedDescription
                )
            }
        }

        if outcome.shouldReconcileRenewalNotifications {
            for account in accounts {
                renewalReminderScheduler.reconcile(
                    account: account,
                    snapshot: snapshots.last(where: { $0.accountId == account.id }),
                    settings: state.settings,
                    notificationManager: notificationManager,
                    now: now
                )
            }
        }

        if outcome.shouldReconcileCooldownNotifications || !recovery.recoveredAccountIDs.isEmpty {
            reconcileCooldownNotifications(
                accounts: accounts,
                snapshots: snapshots,
                settings: state.settings,
                now: now
            )
        }

        let presentation = presentationRuntime.makeMenuBarPresentation(
            accounts: accounts,
            snapshots: snapshots,
            language: language,
            now: now
        )

        return RefreshEngineResult(
            codexRunning: outcome.codexRunning,
            activeCodexEmail: outcome.activeCodexEmail,
            activeClaudeAccountIdentifier: outcome.activeClaudeAccountIdentifier,
            accounts: accounts,
            snapshots: snapshots,
            persistenceErrorDetails: persistenceErrorDetails,
            compactLabel: presentation.compactLabel,
            menuBarState: presentation.menuBarState,
            claudeWebSessionStatus: outcome.claudeWebSessionStatus
        )
    }

    private func reconcileCooldownNotifications(
        accounts: [Account],
        snapshots: [UsageSnapshot],
        settings: AppSettingsState,
        now: Date
    ) {
        for account in accounts {
            if let snapshot = snapshots.last(where: { $0.accountId == account.id }) {
                scheduleCooldownNotificationIfNeeded(
                    snapshot: snapshot,
                    account: account,
                    settings: settings,
                    now: now
                )
            } else {
                notificationManager.cancelCooldownReadyNotification(
                    accountId: account.id,
                    accountName: account.displayName
                )
            }
        }
    }

    private func scheduleCooldownNotificationIfNeeded(
        snapshot: UsageSnapshot,
        account: Account,
        settings: AppSettingsState,
        now: Date
    ) {
        guard settings.cooldownNotificationsEnabled else {
            notificationManager.cancelCooldownReadyNotification(
                accountId: account.id,
                accountName: account.displayName
            )
            return
        }

        guard shouldScheduleResetReadyNotification(snapshot: snapshot, now: now),
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
}

private func mergedErrorDetails(existing: String?, appended: String) -> String {
    guard let existing, !existing.isEmpty else { return appended }
    return existing + "\n" + appended
}
