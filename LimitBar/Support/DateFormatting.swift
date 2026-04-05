import Foundation

func remainingPercent(from usedPercent: Double) -> Double {
    min(max(100 - usedPercent, 0), 100)
}

func expiryDateLabel(_ date: Date, now: Date = .now, language: ResolvedAppLanguage = .english) -> String {
    let strings = AppStrings(language: language)
    if Calendar.current.isDate(date, inSameDayAs: now) {
        return strings.expiresToday
    }
    return strings.expires(localizedMonthDay(date, language: language))
}

func countdownString(until date: Date, now: Date = .now, language: ResolvedAppLanguage = .english) -> String {
    let remaining = max(0, Int(date.timeIntervalSince(now)))
    if remaining == 0 { return AppStrings(language: language).ready }
    let hours = remaining / 3600
    let minutes = (remaining % 3600) / 60
    if hours > 0 {
        return "\(hours)h \(minutes)m"
    }
    if minutes == 0 {
        return "<1m"
    }
    return "\(minutes)m"
}

func hasFutureReset(snapshot: UsageSnapshot, now: Date = .now) -> Bool {
    guard let nextResetAt = snapshot.nextResetAt else { return false }
    return nextResetAt.timeIntervalSince(now) > 0
}

func hasTrackedReset(snapshot: UsageSnapshot) -> Bool {
    snapshot.nextResetAt != nil
}

func isAwaitingReset(snapshot: UsageSnapshot) -> Bool {
    if let session = snapshot.sessionPercentUsed,
       remainingPercent(from: session) <= 0 {
        return true
    }

    switch snapshot.usageStatus {
    case .coolingDown, .exhausted, .stale:
        return true
    case .available, .unknown:
        return false
    }
}

func isResetReady(snapshot: UsageSnapshot, now: Date = .now) -> Bool {
    guard let nextResetAt = snapshot.nextResetAt else { return false }
    return nextResetAt.timeIntervalSince(now) <= 0
}

func shouldShowResetCountdown(snapshot: UsageSnapshot, now: Date = .now) -> Bool {
    guard hasFutureReset(snapshot: snapshot, now: now) else { return false }
    return isAwaitingReset(snapshot: snapshot)
}

func shouldScheduleResetReadyNotification(snapshot: UsageSnapshot, now: Date = .now) -> Bool {
    guard hasFutureReset(snapshot: snapshot, now: now) else { return false }
    return isAwaitingReset(snapshot: snapshot)
}

func shortUsageLabel(snapshot: UsageSnapshot, language: ResolvedAppLanguage = .english) -> String {
    if shouldShowResetCountdown(snapshot: snapshot),
       let nextResetAt = snapshot.nextResetAt {
        return countdownString(until: nextResetAt, language: language)
    }
    if snapshot.usageStatus == .stale {
        return UsageStatus.stale.displayLabel(language: language)
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
    case .stale:       return UsageStatus.stale.displayLabel(language: language)
    }
}

func staleUsageLabel(hasSnapshots: Bool, language: ResolvedAppLanguage = .english) -> String {
    hasSnapshots ? UsageStatus.stale.displayLabel(language: language) : AppStrings(language: language).offline
}

func freshnessLabel(for snapshot: UsageSnapshot, language: ResolvedAppLanguage = .english, now: Date = .now) -> String? {
    let strings = AppStrings(language: language)
    if snapshot.usageStatus == .stale {
        if let lastSyncedAt = snapshot.lastSyncedAt {
            return strings.staleSynced(localizedRelativeDate(lastSyncedAt, language: language, now: now))
        }
        return UsageStatus.stale.displayLabel(language: language)
    }

    guard let lastSyncedAt = snapshot.lastSyncedAt else { return nil }
    return strings.synced(localizedRelativeDate(lastSyncedAt, language: language, now: now))
}
