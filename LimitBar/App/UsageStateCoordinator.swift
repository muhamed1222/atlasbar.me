import Foundation

struct UsageStateProjection: Equatable {
    var accounts: [Account]
    var snapshots: [UsageSnapshot]
    var accountMetadata: [AccountMetadata]
    var settings: AppSettingsState
    var compactLabel: String

    var persistedState: PersistedState {
        PersistedState(
            accounts: accounts,
            snapshots: snapshots,
            accountMetadata: accountMetadata,
            settings: settings
        )
    }
}

struct UsageStateLoadResult: Equatable {
    var state: PersistedState
    var persistenceError: String?
}

struct UsageStateCoordinator: Sendable {
    private let store: (any SnapshotStoring)?
    private let notificationManager: any NotificationScheduling

    init(
        store: (any SnapshotStoring)?,
        notificationManager: any NotificationScheduling
    ) {
        self.store = store
        self.notificationManager = notificationManager
    }

    func loadInitialState() -> UsageStateLoadResult {
        let loaded = store?.load() ?? PersistedState(accounts: [], snapshots: [])
        var persistenceError: String? = store?.lastLoadIssue
        let normalized = normalizedLegacyAccounts(in: loaded)
        let persisted = PersistedState(
            accounts: deduplicated(normalized.accounts),
            snapshots: normalized.snapshots,
            accountMetadata: normalized.accountMetadata,
            settings: normalized.settings
        )
        if persisted != loaded {
            do {
                try store?.save(persisted)
            } catch {
                if let existingError = persistenceError, !existingError.isEmpty {
                    persistenceError = existingError + "\n" + error.localizedDescription
                } else {
                    persistenceError = error.localizedDescription
                }
            }
        }
        return UsageStateLoadResult(state: persisted, persistenceError: persistenceError)
    }

    func resetAll() throws -> UsageStateProjection {
        try store?.reset()
        return UsageStateProjection(
            accounts: [],
            snapshots: [],
            accountMetadata: [],
            settings: .default,
            compactLabel: "--"
        )
    }

    func markStale(from state: PersistedState) throws -> UsageStateProjection {
        let snapshots = state.snapshots.map { snapshot in
            var staleSnapshot = snapshot
            staleSnapshot.usageStatus = .stale
            return staleSnapshot
        }
        try persist(
            accounts: state.accounts,
            snapshots: snapshots,
            accountMetadata: state.accountMetadata,
            settings: state.settings
        )

        return UsageStateProjection(
            accounts: state.accounts,
            snapshots: snapshots,
            accountMetadata: state.accountMetadata,
            settings: state.settings,
            compactLabel: staleCompactLabel(from: snapshots)
        )
    }

    func markProviderStale(
        _ provider: String,
        from state: PersistedState
    ) throws -> UsageStateProjection {
        let providerAccountIds = Set(
            state.accounts
                .filter { $0.provider.caseInsensitiveCompare(provider) == .orderedSame }
                .map(\.id)
        )

        guard !providerAccountIds.isEmpty else {
            return UsageStateProjection(
                accounts: state.accounts,
                snapshots: state.snapshots,
                accountMetadata: state.accountMetadata,
                settings: state.settings,
                compactLabel: compactLabel(from: state.accounts, snapshots: state.snapshots)
            )
        }

        let snapshots = state.snapshots.map { snapshot in
            guard providerAccountIds.contains(snapshot.accountId) else { return snapshot }
            var staleSnapshot = snapshot
            staleSnapshot.usageStatus = .stale
            return staleSnapshot
        }

        try persist(
            accounts: state.accounts,
            snapshots: snapshots,
            accountMetadata: state.accountMetadata,
            settings: state.settings
        )

        return UsageStateProjection(
            accounts: state.accounts,
            snapshots: snapshots,
            accountMetadata: state.accountMetadata,
            settings: state.settings,
            compactLabel: compactLabel(from: state.accounts, snapshots: snapshots)
        )
    }

    func markAccountStale(
        provider: String,
        identifier: String?,
        from state: PersistedState
    ) throws -> UsageStateProjection {
        let matchingAccountIds = Set(
            state.accounts
                .filter { $0.matchesIdentity(provider: provider, identifier: identifier) }
                .map(\.id)
        )

        guard !matchingAccountIds.isEmpty else {
            return UsageStateProjection(
                accounts: state.accounts,
                snapshots: state.snapshots,
                accountMetadata: state.accountMetadata,
                settings: state.settings,
                compactLabel: compactLabel(from: state.accounts, snapshots: state.snapshots)
            )
        }

        let snapshots = state.snapshots.map { snapshot in
            guard matchingAccountIds.contains(snapshot.accountId) else { return snapshot }
            var staleSnapshot = snapshot
            staleSnapshot.usageStatus = .stale
            return staleSnapshot
        }

        try persist(
            accounts: state.accounts,
            snapshots: snapshots,
            accountMetadata: state.accountMetadata,
            settings: state.settings
        )

        return UsageStateProjection(
            accounts: state.accounts,
            snapshots: snapshots,
            accountMetadata: state.accountMetadata,
            settings: state.settings,
            compactLabel: compactLabel(from: state.accounts, snapshots: snapshots)
        )
    }

    func deleteAccount(_ account: Account, from state: PersistedState) throws -> UsageStateProjection {
        let accounts = state.accounts.filter { $0.id != account.id }
        let snapshots = state.snapshots.filter { $0.accountId != account.id }
        let accountMetadata = state.accountMetadata.filter { $0.accountId != account.id }
        notificationManager.cancelCooldownReadyNotification(accountId: account.id, accountName: account.displayName)
        try persist(
            accounts: accounts,
            snapshots: snapshots,
            accountMetadata: accountMetadata,
            settings: state.settings
        )

        return UsageStateProjection(
            accounts: accounts,
            snapshots: snapshots,
            accountMetadata: accountMetadata,
            settings: state.settings,
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
            provider: payload.provider,
            accounts: &accounts
        )
        let previousSnapshot = state.snapshots.last(where: { $0.accountId == accountId })

        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: accountId,
            sessionPercentUsed: payload.sessionPercentUsed,
            weeklyPercentUsed: payload.weeklyPercentUsed,
            nextResetAt: payload.nextResetAt ?? previousSnapshot?.nextResetAt,
            weeklyResetAt: payload.weeklyResetAt ?? previousSnapshot?.weeklyResetAt,
            subscriptionExpiresAt: payload.subscriptionExpiresAt,
            planType: payload.planType ?? previousSnapshot?.planType,
            usageStatus: payload.usageStatus,
            sourceConfidence: payload.sourceConfidence,
            lastSyncedAt: Date(),
            rawExtractedStrings: payload.rawExtractedStrings,
            totalTokensToday: payload.totalTokensToday,
            totalTokensThisWeek: payload.totalTokensThisWeek
        )

        var snapshots = state.snapshots.filter { $0.accountId != accountId } + [snapshot]
        var accountMetadata = state.accountMetadata

        if payload.provider.caseInsensitiveCompare(Provider.claude.name) == .orderedSame,
           let normalizedIdentifier = payload.normalizedAccountIdentifier,
           normalizedIdentifier.contains("@") {
            let cleanup = cleanupLegacyClaudeAccounts(
                preferredAccountId: accountId,
                accounts: accounts,
                snapshots: snapshots,
                accountMetadata: accountMetadata,
                settings: state.settings
            )
            accounts = cleanup.accounts
            snapshots = cleanup.snapshots
            accountMetadata = cleanup.accountMetadata
        }

        try persist(
            accounts: accounts,
            snapshots: snapshots,
            accountMetadata: accountMetadata,
            settings: state.settings
        )
        scheduleNotificationIfNeeded(
            snapshot: snapshot,
            accounts: accounts,
            accountId: accountId,
            settings: state.settings
        )

        return UsageStateProjection(
            accounts: accounts,
            snapshots: snapshots,
            accountMetadata: accountMetadata,
            settings: state.settings,
            compactLabel: shortUsageLabel(snapshot: snapshot)
        )
    }

    private func persist(
        accounts: [Account],
        snapshots: [UsageSnapshot],
        accountMetadata: [AccountMetadata],
        settings: AppSettingsState
    ) throws {
        try store?.save(
            PersistedState(
                accounts: accounts,
                snapshots: snapshots,
                accountMetadata: accountMetadata,
                settings: settings
            )
        )
    }

    private func scheduleNotificationIfNeeded(
        snapshot: UsageSnapshot,
        accounts: [Account],
        accountId: UUID,
        settings: AppSettingsState
    ) {
        guard let account = accounts.first(where: { $0.id == accountId }) else { return }

        guard settings.cooldownNotificationsEnabled else {
            notificationManager.cancelCooldownReadyNotification(accountId: account.id, accountName: account.displayName)
            return
        }

        guard shouldScheduleResetReadyNotification(snapshot: snapshot),
              let nextResetAt = snapshot.nextResetAt else {
            notificationManager.cancelCooldownReadyNotification(accountId: account.id, accountName: account.displayName)
            return
        }

        notificationManager.scheduleCooldownReadyNotification(
            accountId: account.id,
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
        return latestSnapshot.map { shortUsageLabel(snapshot: $0) } ?? staleUsageLabel(hasSnapshots: true)
    }

    private func upsertAccount(
        identifier: String?,
        provider: String,
        accounts: inout [Account]
    ) -> UUID {
        let providerIsClaude = provider.caseInsensitiveCompare(Provider.claude.name) == .orderedSame
        if let identifier,
           let idx = accounts.firstIndex(where: { $0.matchesIdentity(provider: provider, identifier: identifier) }) {
            return accounts[idx].id
        }

        if providerIsClaude,
           let identifier,
           identifier.contains("@"),
           let legacyIndex = accounts.firstIndex(where: { account in
               guard account.provider.caseInsensitiveCompare(provider) == .orderedSame else { return false }
               return isLegacyClaudePlaceholder(account)
           }) {
            accounts[legacyIndex].email = identifier
            accounts[legacyIndex].label = nil
            return accounts[legacyIndex].id
        }

        if identifier == nil,
           let existing = accounts.first(where: {
               $0.matchesIdentity(provider: provider, identifier: nil)
           }) {
            return existing.id
        }

        let isEmail = identifier?.contains("@") == true
        let account = Account(
            id: UUID(),
            provider: provider,
            email: isEmail ? identifier : nil,
            label: isEmail ? nil : identifier
        )
        accounts.append(account)
        return account.id
    }

    private func deduplicated(_ accounts: [Account]) -> [Account] {
        var seen = Set<String>()
        return accounts.filter { account in
            let key = account.identityKey
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    private func normalizedLegacyAccounts(in state: PersistedState) -> PersistedState {
        var removedIds = Set<UUID>()

        let groupedClaudeAccounts = state.accounts.filter {
            $0.provider.caseInsensitiveCompare(Provider.claude.name) == .orderedSame
        }

        let emailAccounts = groupedClaudeAccounts.filter { $0.email != nil }
        let legacyAccounts = groupedClaudeAccounts.filter(isLegacyClaudePlaceholder)

        if emailAccounts.count == 1 {
            let canonical = emailAccounts[0]
            for legacy in legacyAccounts where legacy.id != canonical.id {
                removedIds.insert(legacy.id)
            }
        }

        return PersistedState(
            accounts: state.accounts.filter { !removedIds.contains($0.id) },
            snapshots: state.snapshots.filter { !removedIds.contains($0.accountId) },
            accountMetadata: state.accountMetadata.filter { !removedIds.contains($0.accountId) },
            settings: state.settings
        )
    }

    private func cleanupLegacyClaudeAccounts(
        preferredAccountId: UUID,
        accounts: [Account],
        snapshots: [UsageSnapshot],
        accountMetadata: [AccountMetadata],
        settings: AppSettingsState
    ) -> PersistedState {
        let removedIds = Set(
            accounts
                .filter { $0.id != preferredAccountId && isLegacyClaudePlaceholder($0) }
                .map(\.id)
        )

        guard !removedIds.isEmpty else {
            return PersistedState(
                accounts: accounts,
                snapshots: snapshots,
                accountMetadata: accountMetadata,
                settings: settings
            )
        }

        return PersistedState(
            accounts: accounts.filter { !removedIds.contains($0.id) },
            snapshots: snapshots.filter { !removedIds.contains($0.accountId) },
            accountMetadata: accountMetadata.filter { !removedIds.contains($0.accountId) },
            settings: settings
        )
    }

    private func isLegacyClaudePlaceholder(_ account: Account) -> Bool {
        guard account.provider.caseInsensitiveCompare(Provider.claude.name) == .orderedSame,
              account.email == nil else {
            return false
        }

        let trimmedLabel = account.label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedLabel.isEmpty else { return false }
        return trimmedLabel == "Claude Code" || trimmedLabel.hasPrefix("Claude ")
    }
}
