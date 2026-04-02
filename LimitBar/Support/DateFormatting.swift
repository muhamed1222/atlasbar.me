import Foundation

func remainingPercent(from usedPercent: Double) -> Double {
    min(max(100 - usedPercent, 0), 100)
}

func countdownString(until date: Date, now: Date = .now) -> String {
    let remaining = max(0, Int(date.timeIntervalSince(now)))
    if remaining == 0 { return "Ready" }
    let hours = remaining / 3600
    let minutes = (remaining % 3600) / 60
    if hours > 0 {
        return "\(hours)h \(minutes)m"
    }
    return "\(minutes)m"
}

func shortUsageLabel(snapshot: UsageSnapshot) -> String {
    if snapshot.usageStatus == .stale {
        return UsageStatus.stale.displayLabel
    }
    if let nextResetAt = snapshot.nextResetAt, snapshot.usageStatus == .coolingDown {
        return countdownString(until: nextResetAt)
    }
    if let session = snapshot.sessionPercentUsed, let weekly = snapshot.weeklyPercentUsed {
        return "S\(Int(remainingPercent(from: session))) W\(Int(remainingPercent(from: weekly)))"
    }
    if let session = snapshot.sessionPercentUsed {
        return "S\(Int(remainingPercent(from: session)))"
    }
    switch snapshot.usageStatus {
    case .available:   return "OK"
    case .exhausted:   return "X"
    case .coolingDown: return "~"
    case .unknown:     return "--"
    case .stale:       return UsageStatus.stale.displayLabel
    }
}

func staleUsageLabel(hasSnapshots: Bool) -> String {
    hasSnapshots ? UsageStatus.stale.displayLabel : "Offline"
}

func freshnessLabel(for snapshot: UsageSnapshot) -> String? {
    if snapshot.usageStatus == .stale {
        if let lastSyncedAt = snapshot.lastSyncedAt {
            return "Stale · Synced \(lastSyncedAt.formatted(.relative(presentation: .named)))"
        }
        return UsageStatus.stale.displayLabel
    }

    guard let lastSyncedAt = snapshot.lastSyncedAt else { return nil }
    return "Synced \(lastSyncedAt.formatted(.relative(presentation: .named)))"
}
