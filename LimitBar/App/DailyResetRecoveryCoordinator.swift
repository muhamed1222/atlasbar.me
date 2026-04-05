import Foundation

struct DailyResetRecoveryOutcome: Equatable {
    let snapshots: [UsageSnapshot]
    let recoveredAccountIDs: [UUID]
    let nextRecoveryAt: Date?
}

struct DailyResetRecoveryCoordinator: Sendable {
    func reconcile(
        snapshots: [UsageSnapshot],
        now: Date
    ) -> DailyResetRecoveryOutcome {
        var recoveredAccountIDs: [UUID] = []

        let updatedSnapshots = snapshots.map { snapshot in
            guard shouldRecover(snapshot: snapshot, now: now) else {
                return snapshot
            }

            recoveredAccountIDs.append(snapshot.accountId)

            var recovered = snapshot
            recovered.sessionPercentUsed = 0
            recovered.usageStatus = .available
            recovered.stateOrigin = .predictedReset
            recovered.lastSyncedAt = now
            return recovered
        }

        let nextRecoveryAt = updatedSnapshots
            .filter { shouldScheduleRecoveryTimer(for: $0, now: now) }
            .compactMap(\.nextResetAt)
            .min()

        return DailyResetRecoveryOutcome(
            snapshots: updatedSnapshots,
            recoveredAccountIDs: recoveredAccountIDs,
            nextRecoveryAt: nextRecoveryAt
        )
    }

    private func shouldRecover(snapshot: UsageSnapshot, now: Date) -> Bool {
        guard let nextResetAt = snapshot.nextResetAt else { return false }
        guard nextResetAt <= now else { return false }
        guard snapshot.sessionPercentUsed != nil else { return false }
        return snapshot.usageStatus == .exhausted
            || snapshot.usageStatus == .coolingDown
            || snapshot.usageStatus == .stale
    }

    private func shouldScheduleRecoveryTimer(for snapshot: UsageSnapshot, now: Date) -> Bool {
        guard let nextResetAt = snapshot.nextResetAt else { return false }
        guard nextResetAt > now else { return false }
        guard snapshot.sessionPercentUsed != nil else { return false }
        return snapshot.usageStatus == .exhausted
            || snapshot.usageStatus == .coolingDown
            || snapshot.usageStatus == .stale
    }
}
