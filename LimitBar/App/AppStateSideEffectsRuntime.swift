import Foundation

struct AppStateSideEffectsRuntime: Sendable {
    private let store: (any SnapshotStoring)?
    private let notificationManager: any NotificationScheduling
    private let renewalReminderScheduler: RenewalReminderScheduler

    init(
        store: (any SnapshotStoring)?,
        notificationManager: any NotificationScheduling,
        renewalReminderScheduler: RenewalReminderScheduler = RenewalReminderScheduler()
    ) {
        self.store = store
        self.notificationManager = notificationManager
        self.renewalReminderScheduler = renewalReminderScheduler
    }

    func persist(_ state: PersistedState) throws {
        try store?.save(state)
    }

    func reconcileNotifications(
        in state: PersistedState,
        now: Date = .now
    ) {
        reconcileCooldownNotifications(in: state, now: now)
        reconcileRenewalReminders(in: state, now: now)
    }

    func reconcileCooldownNotifications(
        in state: PersistedState,
        accountIds: [UUID]? = nil,
        now: Date = .now
    ) {
        let targetIds = Set(accountIds ?? state.accounts.map(\.id))
        let snapshotsByAccountId = Dictionary(uniqueKeysWithValues: state.snapshots.map { ($0.accountId, $0) })

        for account in state.accounts where targetIds.contains(account.id) {
            if let snapshot = snapshotsByAccountId[account.id] {
                scheduleCooldownNotificationIfNeeded(
                    snapshot: snapshot,
                    account: account,
                    settings: state.settings,
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

    func reconcileRenewalReminders(
        in state: PersistedState,
        accountIds: [UUID]? = nil,
        now: Date = .now
    ) {
        let targetIds = Set(accountIds ?? state.accounts.map(\.id))
        let snapshotsByAccountId = Dictionary(uniqueKeysWithValues: state.snapshots.map { ($0.accountId, $0) })

        for account in state.accounts where targetIds.contains(account.id) {
            renewalReminderScheduler.reconcile(
                account: account,
                snapshot: snapshotsByAccountId[account.id],
                settings: state.settings,
                notificationManager: notificationManager,
                now: now
            )
        }
    }

    func cancelNotifications(for accounts: [Account]) {
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

    func cancelRenewalReminders(for accounts: [Account]) {
        for account in accounts {
            notificationManager.cancelNotifications(
                withIdentifiers: renewalReminderScheduler.reminderIdentifiers(for: account.id)
            )
        }
    }

    private func scheduleCooldownNotificationIfNeeded(
        snapshot: UsageSnapshot,
        account: Account,
        settings: AppSettingsState,
        now: Date
    ) {
        guard settings.cooldownNotificationsEnabled,
              shouldScheduleResetReadyNotification(snapshot: snapshot, now: now),
              let resetAt = effectiveResetAt(snapshot: snapshot) else {
            notificationManager.cancelCooldownReadyNotification(
                accountId: account.id,
                accountName: account.displayName
            )
            return
        }

        notificationManager.scheduleCooldownReadyNotification(
            accountId: account.id,
            at: resetAt
        )
    }
}
