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

struct AccountRowPresentation: Equatable {
    var title: String
    var usageSummary: PresentationChip?
    var chips: [PresentationChip]
    var usageBars: [UsageBarPresentation]
    var notePreview: String?
    var syncText: String?
}

struct AccountsListRowPresentation: Equatable {
    var title: String
    var priorityChip: PresentationChip?
    var chips: [PresentationChip]
    var notePreview: String?
}

struct AccountDetailPresentation: Equatable {
    struct IdentityRow: Equatable {
        var title: String
        var value: String
    }

    var title: String
    var providerLine: String
    var priorityChip: PresentationChip?
    var summaryChips: [PresentationChip]
    var identityRows: [IdentityRow]
    var noteFooter: String
    var noteCharacterCount: String
}

func makeAccountRowPresentation(
    account: Account,
    snapshot: UsageSnapshot?,
    metadata: AccountMetadata,
    now: Date = .now
) -> AccountRowPresentation {
    let usageSummary = snapshot.map { snapshot in
        PresentationChip(
            text: usageSummaryText(for: snapshot, now: now),
            tone: .secondary,
            style: .outlined,
            monospaced: true
        )
    }

    var chips: [PresentationChip] = [
        PresentationChip(text: account.provider, tone: .secondary, style: .outlined)
    ]

    if let snapshot {
        chips.append(
            PresentationChip(
                text: snapshot.usageStatus.displayLabel,
                tone: tone(for: snapshot.usageStatus),
                style: .filled
            )
        )

        if let nextResetAt = snapshot.nextResetAt, snapshot.usageStatus == .coolingDown {
            chips.append(
                PresentationChip(
                    text: countdownString(until: nextResetAt, now: now),
                    tone: .orange,
                    style: .outlined,
                    monospaced: true
                )
            )
        }

        if let chip = subscriptionChip(for: snapshot, now: now) {
            chips.append(chip)
        }
    } else {
        chips.append(PresentationChip(text: "No data", tone: .secondary, style: .outlined))
    }

    let usageBars = usageBarsPresentation(snapshot: snapshot)
    let syncText = snapshot?.lastSyncedAt.map { "Synced \($0.formatted(.relative(presentation: .named)))" }

    return AccountRowPresentation(
        title: account.displayName,
        usageSummary: usageSummary,
        chips: chips,
        usageBars: usageBars,
        notePreview: metadata.hasNote ? metadata.trimmedNote : nil,
        syncText: syncText
    )
}

func makeAccountsListRowPresentation(
    account: Account,
    snapshot: UsageSnapshot?,
    metadata: AccountMetadata,
    now: Date = .now
) -> AccountsListRowPresentation {
    var chips: [PresentationChip] = [
        PresentationChip(text: account.provider, tone: .secondary, style: .outlined)
    ]

    if let snapshot {
        chips.append(
            PresentationChip(
                text: snapshot.usageStatus.displayLabel,
                tone: tone(for: snapshot.usageStatus),
                style: .filled
            )
        )

        if let chip = subscriptionChip(for: snapshot, now: now) {
            chips.append(chip)
        }
    }

    return AccountsListRowPresentation(
        title: account.displayName,
        priorityChip: metadata.priority == .none
            ? nil
            : PresentationChip(text: metadata.priority.displayLabel, tone: .blue, style: .filled),
        chips: chips,
        notePreview: metadata.hasNote ? metadata.trimmedNote : nil
    )
}

func makeAccountDetailPresentation(
    account: Account,
    snapshot: UsageSnapshot?,
    metadata: AccountMetadata,
    now: Date = .now
) -> AccountDetailPresentation {
    var identityRows = [
        AccountDetailPresentation.IdentityRow(title: "Account", value: account.displayName),
        AccountDetailPresentation.IdentityRow(title: "Provider", value: account.provider),
        AccountDetailPresentation.IdentityRow(title: "Subscription", value: subscriptionText(for: snapshot, now: now))
    ]

    if let lastSyncedAt = snapshot?.lastSyncedAt {
        identityRows.append(
            AccountDetailPresentation.IdentityRow(
                title: "Last sync",
                value: lastSyncedAt.formatted(.relative(presentation: .named))
            )
        )
    }

    var summaryChips: [PresentationChip] = []
    if let snapshot {
        summaryChips.append(
            PresentationChip(
                text: snapshot.usageStatus.displayLabel,
                tone: tone(for: snapshot.usageStatus),
                style: .filled
            )
        )
    } else {
        summaryChips.append(PresentationChip(text: "Unknown status", tone: .secondary, style: .outlined))
    }

    summaryChips.append(
        PresentationChip(
            text: subscriptionText(for: snapshot, now: now),
            tone: subscriptionTone(for: snapshot, now: now),
            style: .outlined
        )
    )

    return AccountDetailPresentation(
        title: account.displayName,
        providerLine: "Provider: \(account.provider)",
        priorityChip: metadata.priority == .none
            ? nil
            : PresentationChip(text: metadata.priority.displayLabel, tone: .blue, style: .filled),
        summaryChips: summaryChips,
        identityRows: identityRows,
        noteFooter: metadata.hasNote
            ? "Saved locally for this account"
            : "Optional note for renewal context, handoff, or reminders",
        noteCharacterCount: "\(metadata.trimmedNote.count) characters"
    )
}

private func usageBarsPresentation(snapshot: UsageSnapshot?) -> [UsageBarPresentation] {
    guard let snapshot else {
        return []
    }

    var bars: [UsageBarPresentation] = []
    if let session = snapshot.sessionPercentUsed {
        bars.append(UsageBarPresentation(label: "S", remainingPercent: Int(remainingPercent(from: session))))
    }
    if let weekly = snapshot.weeklyPercentUsed {
        bars.append(UsageBarPresentation(label: "W", remainingPercent: Int(remainingPercent(from: weekly))))
    }
    return bars
}

private func usageSummaryText(for snapshot: UsageSnapshot, now: Date) -> String {
    if let nextResetAt = snapshot.nextResetAt, snapshot.usageStatus == .coolingDown {
        return countdownString(until: nextResetAt, now: now)
    }
    return shortUsageLabel(snapshot: snapshot)
}

private func subscriptionChip(for snapshot: UsageSnapshot, now: Date) -> PresentationChip? {
    switch SubscriptionDerivedState.from(expiryDate: snapshot.subscriptionExpiresAt, now: now) {
    case .active:
        return PresentationChip(
            text: subscriptionText(for: snapshot, now: now),
            tone: .secondary,
            style: .outlined
        )
    case .expiringSoon:
        return PresentationChip(
            text: subscriptionText(for: snapshot, now: now),
            tone: .orange,
            style: .outlined
        )
    case .expired:
        return PresentationChip(text: "Expired", tone: .red, style: .outlined)
    case .unknown:
        return nil
    }
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

private func subscriptionText(for snapshot: UsageSnapshot?, now: Date) -> String {
    guard let snapshot else {
        return "Unknown"
    }

    switch SubscriptionDerivedState.from(expiryDate: snapshot.subscriptionExpiresAt, now: now) {
    case .active, .expiringSoon:
        guard let expiry = snapshot.subscriptionExpiresAt else {
            return "Unknown"
        }
        return expiryDateLabel(expiry, now: now)
    case .expired:
        return "Expired"
    case .unknown:
        return "Unknown"
    }
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
