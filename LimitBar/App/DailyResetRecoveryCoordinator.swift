import Foundation
import OSLog

private let logger = Logger(subsystem: "me.atlasbar.LimitBar", category: "DailyResetRecovery")

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
            if isWeeklyQuotaExhausted(snapshot: snapshot) {
                recovered.weeklyPercentUsed = 0
                recovered.sessionPercentUsed = 0
            } else {
                recovered.sessionPercentUsed = 0
            }
            recovered.usageStatus = .available
            recovered.stateOrigin = .predictedReset
            recovered.lastSyncedAt = now
            return recovered
        }

        let nextRecoveryAt = updatedSnapshots
            .filter { shouldScheduleRecoveryTimer(for: $0, now: now) }
            .compactMap { effectiveResetAt(snapshot: $0) }
            .min()

        if !recoveredAccountIDs.isEmpty {
            logger.info("Predicted reset for \(recoveredAccountIDs.count) account(s)")
        }
        if let nextRecoveryAt {
            logger.debug("Next predicted reset scheduled at \(nextRecoveryAt)")
        }

        return DailyResetRecoveryOutcome(
            snapshots: updatedSnapshots,
            recoveredAccountIDs: recoveredAccountIDs,
            nextRecoveryAt: nextRecoveryAt
        )
    }

    private func shouldRecover(snapshot: UsageSnapshot, now: Date) -> Bool {
        guard let resetAt = effectiveResetAt(snapshot: snapshot) else { return false }
        guard resetAt <= now else { return false }

        if isWeeklyQuotaExhausted(snapshot: snapshot) {
            guard snapshot.weeklyPercentUsed != nil else { return false }
        } else {
            guard snapshot.sessionPercentUsed != nil else { return false }
        }

        return snapshot.usageStatus == .exhausted
            || snapshot.usageStatus == .coolingDown
            || snapshot.usageStatus == .stale
    }

    private func shouldScheduleRecoveryTimer(for snapshot: UsageSnapshot, now: Date) -> Bool {
        guard let resetAt = effectiveResetAt(snapshot: snapshot) else { return false }
        guard resetAt > now else { return false }

        if isWeeklyQuotaExhausted(snapshot: snapshot) {
            guard snapshot.weeklyPercentUsed != nil else { return false }
        } else {
            guard snapshot.sessionPercentUsed != nil else { return false }
        }

        return snapshot.usageStatus == .exhausted
            || snapshot.usageStatus == .coolingDown
            || snapshot.usageStatus == .stale
    }
}
