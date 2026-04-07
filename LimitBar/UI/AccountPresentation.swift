import Foundation

enum PresentationTone: Equatable {
    case secondary
    case blue
    case green
    case orange
    case red
}

enum PresentationChipStyle: Equatable {
    case filled
    case outlined
}

struct PresentationChip: Equatable {
    var text: String
    var tone: PresentationTone
    var style: PresentationChipStyle
    var monospaced: Bool = false
}

struct UsageBarPresentation: Equatable {
    var label: String
    var remainingPercent: Int
}

private func clampedPercent(_ value: Double) -> Int {
    Int(min(max(value, 0), 100))
}

struct ResetAccentPresentation: Equatable {
    var title: String
    var countdownText: String
    var countdownValue: String
    var timeText: String
    var summaryText: String
    var countdownTone: PresentationTone
}

struct AccountRowPresentation: Equatable {
    var title: String
    var planLabel: String?
    var usageSummary: PresentationChip?
    var chips: [PresentationChip]
    var sourceChip: PresentationChip?
    var statusChip: PresentationChip?
    var subscriptionChip: PresentationChip?
    var resetAccent: ResetAccentPresentation?
    var usageBars: [UsageBarPresentation]
    var notePreview: String?
    var syncText: String?
    var totalTokensToday: Int? = nil
    var totalTokensThisWeek: Int? = nil
}

struct AccountsListRowPresentation: Equatable {
    var title: String
    var priorityChip: PresentationChip?
    var chips: [PresentationChip]
    var resetAccent: ResetAccentPresentation?
    var notePreview: String?
}

struct AccountDetailPresentation: Equatable {
    struct IdentityRow: Equatable {
        var title: String
        var value: String
    }

    var title: String
    var providerLine: String
    var planLabel: String?
    var priorityChip: PresentationChip?
    var summaryChips: [PresentationChip]
    var resetAccent: ResetAccentPresentation?
    var identityRows: [IdentityRow]
    var noteFooter: String
    var noteCharacterCount: String
}

enum DataQualityState: Equatable {
    case live
    case cached
    case stale
    case localOnly
}

func makeAccountRowPresentation(
    account: Account,
    snapshot: UsageSnapshot?,
    metadata: AccountMetadata,
    now: Date = .now,
    language: ResolvedAppLanguage = .english
) -> AccountRowPresentation {
    let strings = AppStrings(language: language)
    let statusChip = rowStatusChip(for: snapshot, language: language)
    let sourceChip = dataQualityChip(for: account, snapshot: snapshot, language: language)
    let rowSubscriptionChip: PresentationChip? = snapshot.flatMap { item in
        subscriptionChip(for: item, now: now, language: language)
    }
    let usageSummary = snapshot.map { snapshot in
        PresentationChip(
            text: usageSummaryText(for: snapshot, now: now, language: language),
            tone: .secondary,
            style: .outlined,
            monospaced: true
        )
    }

    var chips: [PresentationChip] = [
        PresentationChip(text: account.provider.name, tone: .secondary, style: .outlined)
    ]
    let resetAccent = resetAccent(for: snapshot, now: now, language: language)

    if let snapshot {
        if let sourceChip {
            chips.append(sourceChip)
        }

        if shouldIncludeUsageStatusBadge(snapshot) {
            chips.append(
                PresentationChip(
                    text: snapshot.usageStatus.displayLabel(language: language),
                    tone: tone(for: snapshot.usageStatus),
                    style: .filled
                )
            )
        }

        if resetAccent == nil,
           shouldShowResetCountdown(snapshot: snapshot, now: now),
           let nextResetAt = snapshot.nextResetAt {
            chips.append(
                PresentationChip(
                    text: countdownString(until: nextResetAt, now: now, language: language),
                    tone: .orange,
                    style: .outlined,
                    monospaced: true
                )
            )
        }

        if let chip = subscriptionChip(for: snapshot, now: now, language: language) {
            chips.append(chip)
        }
    } else {
        chips.append(PresentationChip(text: strings.noData, tone: .secondary, style: .outlined))
    }

    let usageBars = usageBarsPresentation(snapshot: snapshot, provider: account.provider)
    let syncText = snapshot?.lastSyncedAt.map {
        strings.synced(localizedRelativeDate($0, language: language, now: now))
    }

    var tokenSyncText: String? = syncText
    if account.provider.isClaude, let snapshot {
        if let tokensToday = snapshot.totalTokensToday {
            let formatted = strings.formattedTokens(tokensToday)
            tokenSyncText = "\(strings.tokensToday): \(formatted)"
        }
    }

    return AccountRowPresentation(
        title: account.displayName,
        planLabel: planBadgeText(for: snapshot?.planType),
        usageSummary: usageSummary,
        chips: chips,
        sourceChip: sourceChip,
        statusChip: statusChip,
        subscriptionChip: rowSubscriptionChip,
        resetAccent: resetAccent,
        usageBars: usageBars,
        notePreview: metadata.hasNote ? metadata.trimmedNote : nil,
        syncText: tokenSyncText,
        totalTokensToday: snapshot?.totalTokensToday,
        totalTokensThisWeek: snapshot?.totalTokensThisWeek
    )
}

func makeAccountsListRowPresentation(
    account: Account,
    snapshot: UsageSnapshot?,
    metadata: AccountMetadata,
    now: Date = .now,
    language: ResolvedAppLanguage = .english
) -> AccountsListRowPresentation {
    var chips: [PresentationChip] = [
        PresentationChip(text: account.provider.name, tone: .secondary, style: .outlined)
    ]

    if let snapshot {
        if let sourceChip = dataQualityChip(for: account, snapshot: snapshot, language: language) {
            chips.append(sourceChip)
        }

        if shouldIncludeUsageStatusBadge(snapshot) {
            chips.append(
                PresentationChip(
                    text: snapshot.usageStatus.displayLabel(language: language),
                    tone: tone(for: snapshot.usageStatus),
                    style: .filled
                )
            )
        }

        if let chip = subscriptionChip(for: snapshot, now: now, language: language) {
            chips.append(chip)
        }
    }

    return AccountsListRowPresentation(
        title: account.displayName,
        priorityChip: metadata.priority == .none
            ? nil
            : PresentationChip(text: metadata.priority.displayLabel(language: language), tone: .blue, style: .filled),
        chips: chips,
        resetAccent: resetAccent(for: snapshot, now: now, language: language),
        notePreview: metadata.hasNote ? metadata.trimmedNote : nil
    )
}

func makeAccountDetailPresentation(
    account: Account,
    snapshot: UsageSnapshot?,
    metadata: AccountMetadata,
    now: Date = .now,
    language: ResolvedAppLanguage = .english
) -> AccountDetailPresentation {
    let strings = AppStrings(language: language)
    var identityRows = [
        AccountDetailPresentation.IdentityRow(title: strings.account, value: account.displayName),
        AccountDetailPresentation.IdentityRow(title: strings.provider, value: account.provider.name),
        AccountDetailPresentation.IdentityRow(title: strings.subscription, value: subscriptionText(for: snapshot, now: now, language: language))
    ]

    if let planLabel = planBadgeText(for: snapshot?.planType) {
        identityRows.insert(
            AccountDetailPresentation.IdentityRow(title: strings.plan, value: planLabel),
            at: 2
        )
    }

    if let lastSyncedAt = snapshot?.lastSyncedAt {
        identityRows.append(
            AccountDetailPresentation.IdentityRow(
                title: strings.lastSync,
                value: localizedRelativeDate(lastSyncedAt, language: language, now: now)
            )
        )
    }

    var summaryChips: [PresentationChip] = []
    if let snapshot {
        if let sourceChip = dataQualityChip(for: account, snapshot: snapshot, language: language) {
            summaryChips.append(sourceChip)
        }

        if shouldIncludeUsageStatusBadge(snapshot) {
            summaryChips.append(
                PresentationChip(
                    text: snapshot.usageStatus.displayLabel(language: language),
                    tone: tone(for: snapshot.usageStatus),
                    style: .filled
                )
            )
        }
    } else {
        summaryChips.append(PresentationChip(text: strings.unknownStatus, tone: .secondary, style: .outlined))
    }

    summaryChips.append(
        PresentationChip(
            text: subscriptionText(for: snapshot, now: now, language: language),
            tone: subscriptionTone(for: snapshot, now: now),
            style: .outlined
        )
    )

    return AccountDetailPresentation(
        title: account.displayName,
        providerLine: "\(strings.provider): \(account.provider.name)",
        planLabel: planBadgeText(for: snapshot?.planType),
        priorityChip: metadata.priority == .none
            ? nil
            : PresentationChip(text: metadata.priority.displayLabel(language: language), tone: .blue, style: .filled),
        summaryChips: summaryChips,
        resetAccent: resetAccent(for: snapshot, now: now, language: language),
        identityRows: identityRows,
        noteFooter: metadata.hasNote
            ? strings.savedLocalNoteFooter
            : strings.optionalNoteFooter,
        noteCharacterCount: strings.charactersCount(metadata.trimmedNote.count)
    )
}

private func usageBarsPresentation(snapshot: UsageSnapshot?, provider _: Provider) -> [UsageBarPresentation] {
    guard let snapshot else {
        return []
    }

    var bars: [UsageBarPresentation] = []

    if let session = snapshot.sessionPercentUsed {
        bars.append(
            UsageBarPresentation(label: "S", remainingPercent: clampedPercent(remainingPercent(from: session)))
        )
    }
    if let weekly = snapshot.weeklyPercentUsed {
        bars.append(
            UsageBarPresentation(label: "W", remainingPercent: clampedPercent(remainingPercent(from: weekly)))
        )
    }
    return bars
}

private func usageSummaryText(for snapshot: UsageSnapshot, now: Date, language: ResolvedAppLanguage) -> String {
    if shouldShowResetCountdown(snapshot: snapshot, now: now),
       let nextResetAt = snapshot.nextResetAt {
        return countdownString(until: nextResetAt, now: now, language: language)
    }
    return shortUsageLabel(snapshot: snapshot, language: language)
}

private func resetAccent(for snapshot: UsageSnapshot?, now: Date, language: ResolvedAppLanguage) -> ResetAccentPresentation? {
    guard let nextResetAt = snapshot?.nextResetAt else {
        return nil
    }

    let strings = AppStrings(language: language)
    let timeText = localizedTimeOfDay(nextResetAt, language: language)

    if nextResetAt.timeIntervalSince(now) <= 0 {
        return ResetAccentPresentation(
            title: strings.sessionReset,
            countdownText: strings.ready,
            countdownValue: strings.ready,
            timeText: timeText,
            summaryText: strings.sessionResetReadySummary(time: timeText),
            countdownTone: .green
        )
    }

    let countdown = resetCountdownString(until: nextResetAt, now: now, language: language)
    let countdownText = strings.resetsIn(countdown)
    return ResetAccentPresentation(
        title: strings.sessionReset,
        countdownText: countdownText,
        countdownValue: countdown,
        timeText: timeText,
        summaryText: strings.sessionResetSummary(time: timeText, countdown: countdown),
        countdownTone: .orange
    )
}

private func subscriptionChip(for snapshot: UsageSnapshot, now: Date, language: ResolvedAppLanguage) -> PresentationChip? {
    let strings = AppStrings(language: language)
    switch SubscriptionDerivedState.from(expiryDate: snapshot.subscriptionExpiresAt, now: now) {
    case .active:
        return PresentationChip(
            text: subscriptionText(for: snapshot, now: now, language: language),
            tone: .secondary,
            style: .outlined
        )
    case .expiringSoon:
        return PresentationChip(
            text: subscriptionText(for: snapshot, now: now, language: language),
            tone: .orange,
            style: .outlined
        )
    case .expired:
        return PresentationChip(text: strings.expired, tone: .red, style: .outlined)
    case .unknown:
        return nil
    }
}

private func resetCountdownString(until date: Date, now: Date, language: ResolvedAppLanguage) -> String {
    let remaining = max(0, Int(date.timeIntervalSince(now)))
    let hours = remaining / 3600
    let minutes = (remaining % 3600) / 60

    if hours > 0, minutes == 0 {
        return "\(hours)h"
    }
    if hours > 0 {
        return "\(hours)h \(minutes)m"
    }
    if minutes > 0 {
        return "\(minutes)m"
    }
    return AppStrings(language: language).ready.lowercased()
}

private func subscriptionTone(for snapshot: UsageSnapshot?, now: Date) -> PresentationTone {
    guard let snapshot else {
        return .secondary
    }

    switch SubscriptionDerivedState.from(expiryDate: snapshot.subscriptionExpiresAt, now: now) {
    case .active:
        return .secondary
    case .expiringSoon:
        return .orange
    case .expired:
        return .red
    case .unknown:
        return .secondary
    }
}

private func subscriptionText(for snapshot: UsageSnapshot?, now: Date, language: ResolvedAppLanguage) -> String {
    let strings = AppStrings(language: language)
    guard let snapshot else {
        return strings.unknownStatus
    }

    switch SubscriptionDerivedState.from(expiryDate: snapshot.subscriptionExpiresAt, now: now) {
    case .active, .expiringSoon:
        guard let expiry = snapshot.subscriptionExpiresAt else {
            return strings.unknownStatus
        }
        return expiryDateLabel(expiry, now: now, language: language)
    case .expired:
        return strings.expired
    case .unknown:
        return strings.unknownStatus
    }
}

private func dataQualityChip(
    for account: Account,
    snapshot: UsageSnapshot?,
    language: ResolvedAppLanguage
) -> PresentationChip? {
    guard let snapshot,
          let quality = dataQualityState(for: account, snapshot: snapshot) else {
        return nil
    }

    let strings = AppStrings(language: language)
    return PresentationChip(
        text: strings.dataQualityLabel(quality),
        tone: tone(for: quality),
        style: .outlined
    )
}

private func dataQualityState(for account: Account, snapshot: UsageSnapshot) -> DataQualityState? {
    if snapshot.usageStatus == .stale {
        return .stale
    }

    if isLocalOnlySnapshot(account: account, snapshot: snapshot) {
        return .localOnly
    }

    if snapshot.sourceConfidence < 0.95 {
        return .cached
    }

    return .live
}

private func isLocalOnlySnapshot(account: Account, snapshot: UsageSnapshot) -> Bool {
    guard account.provider.isClaude else {
        return false
    }

    let hasTokenActivity = snapshot.totalTokensToday != nil || snapshot.totalTokensThisWeek != nil
    let hasQuotaData = snapshot.sessionPercentUsed != nil || snapshot.weeklyPercentUsed != nil
    return hasTokenActivity && !hasQuotaData
}

private func planBadgeText(for rawPlanType: String?) -> String? {
    guard let rawPlanType = rawPlanType?.trimmingCharacters(in: .whitespacesAndNewlines),
          !rawPlanType.isEmpty else {
        return nil
    }

    let normalized = rawPlanType.lowercased()
    let knownPlans: [(keyword: String, label: String, exact: Bool)] = [
        ("enterprise", "Enterprise", false),
        ("team", "Team", false),
        ("plus", "Plus", false),
        ("pro", "Pro", false),
        ("go", "Go", true),
        ("free", "Free", false),
    ]
    if let match = knownPlans.first(where: { plan in
        plan.exact ? normalized == plan.keyword : normalized.contains(plan.keyword)
    }) {
        return match.label
    }

    return rawPlanType.prefix(1).uppercased() + rawPlanType.dropFirst()
}

private func rowStatusChip(for snapshot: UsageSnapshot?, language: ResolvedAppLanguage) -> PresentationChip? {
    guard let snapshot else {
        return nil
    }

    guard snapshot.usageStatus != .available, snapshot.usageStatus != .stale else {
        return nil
    }

    return PresentationChip(
        text: snapshot.usageStatus.displayLabel(language: language),
        tone: tone(for: snapshot.usageStatus),
        style: .filled
    )
}

private func shouldIncludeUsageStatusBadge(_ snapshot: UsageSnapshot) -> Bool {
    snapshot.usageStatus != .stale
}

private func tone(for status: UsageStatus) -> PresentationTone {
    switch status {
    case .available:
        return .green
    case .coolingDown:
        return .orange
    case .exhausted:
        return .red
    case .unknown, .stale:
        return .secondary
    }
}

private func tone(for quality: DataQualityState) -> PresentationTone {
    switch quality {
    case .live:
        return .green
    case .cached:
        return .orange
    case .stale:
        return .secondary
    case .localOnly:
        return .blue
    }
}
