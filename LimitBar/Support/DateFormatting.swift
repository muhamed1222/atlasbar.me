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
    case .stale, .unknown: return "--"
    }
}
