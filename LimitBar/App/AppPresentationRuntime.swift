import Foundation

struct MenuBarPresentationProjection: Equatable {
    let compactLabel: String
    let menuBarState: MenuBarState
}

struct AppPresentationProjection: Equatable {
    let compactLabel: String
    let menuBarState: MenuBarState
    let sortedAccounts: [Account]
}

struct AppPresentationRuntime: Sendable {
    func makeProjection(
        accounts: [Account],
        snapshots: [UsageSnapshot],
        accountMetadata: [AccountMetadata],
        language: ResolvedAppLanguage,
        now: Date = .now
    ) -> AppPresentationProjection {
        let menuBarPresentation = makeMenuBarPresentation(
            accounts: accounts,
            snapshots: snapshots,
            language: language,
            now: now
        )
        return AppPresentationProjection(
            compactLabel: menuBarPresentation.compactLabel,
            menuBarState: menuBarPresentation.menuBarState,
            sortedAccounts: sortAccounts(
                accounts: accounts,
                accountMetadata: accountMetadata,
                snapshots: snapshots
            )
        )
    }

    func makeMenuBarPresentation(
        accounts: [Account],
        snapshots: [UsageSnapshot],
        language: ResolvedAppLanguage,
        now: Date = .now
    ) -> MenuBarPresentationProjection {
        guard !accounts.isEmpty else {
            return MenuBarPresentationProjection(compactLabel: "--", menuBarState: .noData)
        }

        let liveSnapshots = snapshots.filter { $0.usageStatus != .stale && $0.usageStatus != .unknown }
        guard !liveSnapshots.isEmpty else {
            let nextReset = snapshots
                .filter { shouldScheduleResetReadyNotification(snapshot: $0, now: now) }
                .compactMap { effectiveResetAt(snapshot: $0) }
                .min()

            if let nextReset {
                return MenuBarPresentationProjection(
                    compactLabel: countdownString(until: nextReset, now: now, language: language),
                    menuBarState: .allCoolingDown(nextResetAt: nextReset)
                )
            }

            return MenuBarPresentationProjection(
                compactLabel: staleUsageLabel(hasSnapshots: !snapshots.isEmpty, language: language),
                menuBarState: .noData
            )
        }

        let available = liveSnapshots.filter { $0.usageStatus == .available }
        let waitingForReset = liveSnapshots.filter { shouldScheduleResetReadyNotification(snapshot: $0, now: now) }

        if available.isEmpty {
            let nextReset = waitingForReset.compactMap { effectiveResetAt(snapshot: $0) }.min()
            if let nextReset {
                return MenuBarPresentationProjection(
                    compactLabel: countdownString(until: nextReset, now: now, language: language),
                    menuBarState: .allCoolingDown(nextResetAt: nextReset)
                )
            }

            return MenuBarPresentationProjection(
                compactLabel: "~",
                menuBarState: .allCoolingDown(nextResetAt: nil)
            )
        }

        let bestSnapshot: UsageSnapshot = available
            .filter { $0.sessionPercentUsed != nil }
            .max(by: {
                remainingPercent(from: $0.sessionPercentUsed ?? 100) <
                remainingPercent(from: $1.sessionPercentUsed ?? 100)
            }) ?? available.max(by: {
                ($0.lastSyncedAt ?? .distantPast) < ($1.lastSyncedAt ?? .distantPast)
            }) ?? available[0]

        let hasGoodHeadroom = available.contains {
            guard let session = $0.sessionPercentUsed else { return true }
            return remainingPercent(from: session) > 30
        }

        return MenuBarPresentationProjection(
            compactLabel: shortUsageLabel(snapshot: bestSnapshot, language: language),
            menuBarState: hasGoodHeadroom ? .available : .low
        )
    }

    func sortAccounts(
        accounts: [Account],
        accountMetadata: [AccountMetadata],
        snapshots: [UsageSnapshot]
    ) -> [Account] {
        let metadataByAccountId = Dictionary(uniqueKeysWithValues: accountMetadata.map { ($0.accountId, $0) })
        let lastSyncedByAccountId = Dictionary(
            uniqueKeysWithValues: snapshots.map { ($0.accountId, $0.lastSyncedAt ?? .distantPast) }
        )

        return accounts.sorted { lhs, rhs in
            let lhsMetadata = metadataByAccountId[lhs.id] ?? AccountMetadata(accountId: lhs.id)
            let rhsMetadata = metadataByAccountId[rhs.id] ?? AccountMetadata(accountId: rhs.id)
            if lhsMetadata.priority.sortWeight != rhsMetadata.priority.sortWeight {
                return lhsMetadata.priority.sortWeight < rhsMetadata.priority.sortWeight
            }

            let lhsLastSynced = lastSyncedByAccountId[lhs.id] ?? .distantPast
            let rhsLastSynced = lastSyncedByAccountId[rhs.id] ?? .distantPast
            if lhsLastSynced != rhsLastSynced {
                return lhsLastSynced > rhsLastSynced
            }

            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }
}
