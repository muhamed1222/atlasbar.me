import Foundation

enum ResetWindowKind: Equatable {
    case session
    case weekly
}

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
    return localizedShortDurationString(
        remainingSeconds: remaining,
        language: language,
        dropsZeroMinutesWhenHoursPresent: false,
        zeroText: AppStrings(language: language).ready
    )
}

func isSessionQuotaExhausted(snapshot: UsageSnapshot) -> Bool {
    guard let session = snapshot.sessionPercentUsed else { return false }
    return session >= 100
}

func isWeeklyQuotaExhausted(snapshot: UsageSnapshot) -> Bool {
    guard let weekly = snapshot.weeklyPercentUsed else { return false }
    return weekly >= 100
}

func effectiveResetWindow(for snapshot: UsageSnapshot) -> ResetWindowKind? {
    if isWeeklyQuotaExhausted(snapshot: snapshot), snapshot.weeklyResetAt != nil {
        return .weekly
    }
    if snapshot.nextResetAt != nil {
        return .session
    }
    if snapshot.weeklyResetAt != nil {
        return .weekly
    }
    return nil
}

func effectiveResetAt(snapshot: UsageSnapshot) -> Date? {
    switch effectiveResetWindow(for: snapshot) {
    case .session:
        return snapshot.nextResetAt
    case .weekly:
        return snapshot.weeklyResetAt
    case nil:
        return nil
    }
}

func hasFutureReset(snapshot: UsageSnapshot, now: Date = .now) -> Bool {
    guard let resetAt = effectiveResetAt(snapshot: snapshot) else { return false }
    return resetAt.timeIntervalSince(now) > 0
}

func isAwaitingReset(snapshot: UsageSnapshot) -> Bool {
    if isWeeklyQuotaExhausted(snapshot: snapshot) || isSessionQuotaExhausted(snapshot: snapshot) {
        return true
    }

    switch snapshot.usageStatus {
    case .coolingDown:
        return true
    case .exhausted, .stale:
        return effectiveResetAt(snapshot: snapshot) != nil
    case .available, .unknown:
        return false
    }
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
       let resetAt = effectiveResetAt(snapshot: snapshot) {
        return countdownString(until: resetAt, language: language)
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

func compactMenuBarLabel(from label: String) -> String {
    let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
    let components = trimmed.split(separator: " ")

    if components.count == 2 {
        let session = String(components[0])
        let weekly = String(components[1])

        guard session.hasPrefix("S"),
              weekly.hasPrefix("W"),
              session.dropFirst().allSatisfy(\.isNumber),
              weekly.dropFirst().allSatisfy(\.isNumber) else {
            return trimmed
        }

        return "\(session.dropFirst())%"
    }

    if trimmed.hasPrefix("S"), trimmed.dropFirst().allSatisfy(\.isNumber) {
        return "\(trimmed.dropFirst())%"
    }

    return trimmed
}

func compactMenuBarLabel(snapshot: UsageSnapshot, language: ResolvedAppLanguage = .english) -> String {
    if shouldShowResetCountdown(snapshot: snapshot) || isWeeklyQuotaExhausted(snapshot: snapshot) {
        return compactMenuBarLabel(from: shortUsageLabel(snapshot: snapshot, language: language))
    }

    if let session = snapshot.sessionPercentUsed {
        return "\(Int(remainingPercent(from: session)))%"
    }

    return compactMenuBarLabel(from: shortUsageLabel(snapshot: snapshot, language: language))
}

func compactMenuBarLabel(
    snapshot: UsageSnapshot,
    provider: Provider,
    language: ResolvedAppLanguage = .english
) -> String {
    if provider.isClaude {
        if let session = snapshot.sessionPercentUsed {
            return "\(Int(remainingPercent(from: session)))%"
        }
    }

    return compactMenuBarLabel(snapshot: snapshot, language: language)
}

struct CompactMenuBarItem: Equatable {
    var provider: Provider
    var label: String
}

func compactMenuBarItems(
    accounts: [Account],
    snapshots: [UsageSnapshot],
    language: ResolvedAppLanguage = .english
) -> [CompactMenuBarItem] {
    let accountsById = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
    let accountProviders = Set(accounts.map(\.provider))
    let snapshotProviders = Set(snapshots.compactMap { accountsById[$0.accountId]?.provider })
    let knownProviders = accountProviders.union(snapshotProviders)

    guard !knownProviders.isEmpty else {
        return [CompactMenuBarItem(provider: .codex, label: "--")]
    }

    var orderedProviders: [Provider] = []
    if knownProviders.contains(.codex) {
        orderedProviders.append(.codex)
    }
    if knownProviders.contains(.claude) {
        orderedProviders.append(.claude)
    }

    return orderedProviders.map { provider in
        let latestSnapshot = snapshots
            .filter { snapshot in
                accountsById[snapshot.accountId]?.provider == provider
            }
            .max(by: { ($0.lastSyncedAt ?? .distantPast) < ($1.lastSyncedAt ?? .distantPast) })

        let label = latestSnapshot.map {
            compactMenuBarLabel(snapshot: $0, provider: provider, language: language)
        } ?? "--"

        return CompactMenuBarItem(provider: provider, label: label)
    }
}

func localizedShortDurationString(
    remainingSeconds: Int,
    language: ResolvedAppLanguage = .english,
    dropsZeroMinutesWhenHoursPresent: Bool,
    zeroText: String? = nil
) -> String {
    let strings = AppStrings(language: language)
    let remaining = max(0, remainingSeconds)

    if remaining == 0 {
        return zeroText ?? strings.ready
    }

    let hours = remaining / 3600
    let minutes = (remaining % 3600) / 60

    if hours > 0, dropsZeroMinutesWhenHoursPresent, minutes == 0 {
        return "\(hours)\(strings.shortHourUnit)"
    }

    if hours > 0 {
        return "\(hours)\(strings.shortHourUnit) \(minutes)\(strings.shortMinuteUnit)"
    }

    if minutes == 0 {
        return strings.lessThanOneMinute
    }

    return "\(minutes)\(strings.shortMinuteUnit)"
}

func staleUsageLabel(hasSnapshots: Bool, language: ResolvedAppLanguage = .english) -> String {
    hasSnapshots ? UsageStatus.stale.displayLabel(language: language) : AppStrings(language: language).offline
}
