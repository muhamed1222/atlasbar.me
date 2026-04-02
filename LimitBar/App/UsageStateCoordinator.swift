import Foundation

struct UsageStateProjection: Equatable {
    var accounts: [Account]
    var snapshots: [UsageSnapshot]
    var compactLabel: String
}

struct UsageStateCoordinator {
    private let store: (any SnapshotStoring)?
    private let notificationManager: any NotificationScheduling

    init(
        store: (any SnapshotStoring)?,
        notificationManager: any NotificationScheduling
    ) {
        self.store = store
        self.notificationManager = notificationManager
    }

    func loadInitialState() -> PersistedState {
        let loaded = store?.load() ?? PersistedState(accounts: [], snapshots: [])
        return PersistedState(
            accounts: deduplicated(loaded.accounts),
            snapshots: loaded.snapshots
        )
    }

    func resetAll() throws -> UsageStateProjection {
        try store?.reset()
        return UsageStateProjection(
            accounts: [],
            snapshots: [],
            compactLabel: "--"
        )
    }

    func markStale(from state: PersistedState) throws -> UsageStateProjection {
        let snapshots = state.snapshots.map { snapshot in
            var staleSnapshot = snapshot
            staleSnapshot.usageStatus = .stale
            return staleSnapshot
        }
        try persist(accounts: state.accounts, snapshots: snapshots)

        return UsageStateProjection(
            accounts: state.accounts,
            snapshots: snapshots,
            compactLabel: staleCompactLabel(from: snapshots)
        )
    }

    func deleteAccount(_ account: Account, from state: PersistedState) throws -> UsageStateProjection {
        let accounts = state.accounts.filter { $0.id != account.id }
        let snapshots = state.snapshots.filter { $0.accountId != account.id }
        notificationManager.cancelNotification(for: account.displayName)
        try persist(accounts: accounts, snapshots: snapshots)

        return UsageStateProjection(
            accounts: accounts,
            snapshots: snapshots,
            compactLabel: compactLabel(from: accounts, snapshots: snapshots)
        )
    }

    func applyRefresh(
        _ payload: CurrentUsagePayload,
        to state: PersistedState
    ) throws -> UsageStateProjection {
        var accounts = state.accounts
        let accountId = upsertAccount(
            identifier: payload.accountIdentifier,
            planType: payload.planType,
            accounts: &accounts
        )

        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: accountId,
            sessionPercentUsed: payload.sessionPercentUsed,
            weeklyPercentUsed: payload.weeklyPercentUsed,
            nextResetAt: payload.nextResetAt,
            subscriptionExpiresAt: payload.subscriptionExpiresAt,
            usageStatus: payload.usageStatus,
            subscriptionStatus: .unknown,
            sourceConfidence: payload.sourceConfidence,
            lastSyncedAt: Date(),
            rawExtractedStrings: payload.rawExtractedStrings
        )

        let snapshots = state.snapshots.filter { $0.accountId != accountId } + [snapshot]
        try persist(accounts: accounts, snapshots: snapshots)
        scheduleNotificationIfNeeded(snapshot: snapshot, accounts: accounts, accountId: accountId)

        return UsageStateProjection(
            accounts: accounts,
            snapshots: snapshots,
            compactLabel: shortUsageLabel(snapshot: snapshot)
        )
    }

    private func persist(accounts: [Account], snapshots: [UsageSnapshot]) throws {
        try store?.save(PersistedState(accounts: accounts, snapshots: snapshots))
    }

    private func scheduleNotificationIfNeeded(
        snapshot: UsageSnapshot,
        accounts: [Account],
        accountId: UUID
    ) {
        guard let nextResetAt = snapshot.nextResetAt,
              let account = accounts.first(where: { $0.id == accountId }) else { return }
        notificationManager.scheduleCooldownReadyNotification(
            accountName: account.displayName,
            at: nextResetAt
        )
    }

    private func compactLabel(from accounts: [Account], snapshots: [UsageSnapshot]) -> String {
        guard !accounts.isEmpty else { return "--" }
        guard let latestSnapshot = snapshots.sorted(by: {
            ($0.lastSyncedAt ?? .distantPast) > ($1.lastSyncedAt ?? .distantPast)
        }).first else {
            return "--"
        }
        return shortUsageLabel(snapshot: latestSnapshot)
    }

    private func staleCompactLabel(from snapshots: [UsageSnapshot]) -> String {
        guard !snapshots.isEmpty else {
            return staleUsageLabel(hasSnapshots: false)
        }
        let latestSnapshot = snapshots.sorted(by: {
            ($0.lastSyncedAt ?? .distantPast) > ($1.lastSyncedAt ?? .distantPast)
        }).first
        return latestSnapshot.map(shortUsageLabel) ?? staleUsageLabel(hasSnapshots: true)
    }

    private func upsertAccount(
        identifier: String?,
        planType: String?,
        accounts: inout [Account]
    ) -> UUID {
        if let identifier,
           let idx = accounts.firstIndex(where: { $0.email == identifier || $0.label == identifier }) {
            if let planType, accounts[idx].note != planType {
                accounts[idx].note = planType
            }
            return accounts[idx].id
        }
        if identifier == nil,
           let existing = accounts.first(where: {
               $0.provider == Provider.codex.name && $0.email == nil && $0.label == nil
           }) {
            return existing.id
        }

        let isEmail = identifier?.contains("@") == true
        let account = Account(
            id: UUID(),
            provider: Provider.codex.name,
            email: isEmail ? identifier : nil,
            label: isEmail ? nil : identifier,
            note: planType,
            priority: nil
        )
        accounts.append(account)
        return account.id
    }

    private func deduplicated(_ accounts: [Account]) -> [Account] {
        var seen = Set<String>()
        return accounts.filter { account in
            let key = account.email ?? account.label ?? "__unknown__\(account.provider)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }
}
