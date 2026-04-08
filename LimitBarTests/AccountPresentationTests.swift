import Foundation
import Testing
@testable import LimitBar

struct AccountPresentationTests {
    @Test
    func accountRowPresentationIncludesUsageStatusExpiryAndBars() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let account = Account(id: UUID(), provider: "Codex", email: "row@example.com", label: nil)
        let metadata = AccountMetadata(accountId: account.id, priority: .primary, note: "Use for overflow")
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: 28,
            weeklyPercentUsed: 40,
            nextResetAt: nil,
            subscriptionExpiresAt: now.addingTimeInterval(4 * 24 * 60 * 60),
            planType: "pro",
            usageStatus: .available,
            sourceConfidence: 1,
            lastSyncedAt: now,
            rawExtractedStrings: []
        )

        let presentation = makeAccountRowPresentation(
            account: account,
            snapshot: snapshot,
            metadata: metadata,
            now: now
        )

        #expect(presentation.title == "row@example.com")
        #expect(presentation.planLabel == "Pro")
        #expect(presentation.usageSummary?.text == "S72 W60")
        #expect(presentation.chips.map(\.text) == ["Codex", "Live", "Available", "Expires Jan 16"])
        #expect(presentation.sourceChip?.text == "Live")
        #expect(presentation.statusChip == nil)
        #expect(presentation.subscriptionChip?.text == "Expires Jan 16")
        #expect(presentation.resetAccent == nil)
        #expect(presentation.chips.map(\.tone) == [.secondary, .green, .green, .orange])
        #expect(presentation.usageBars == [
            UsageBarPresentation(label: "S", remainingPercent: 72),
            UsageBarPresentation(label: "W", remainingPercent: 60)
        ])
        #expect(presentation.notePreview == "Use for overflow")
    }

    @Test
    func claudeAccountRowPresentationShowsRemainingPercentsInBars() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let account = Account(id: UUID(), provider: "Claude", email: "claude@example.com", label: nil)
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: 100,
            weeklyPercentUsed: 92,
            nextResetAt: nil,
            subscriptionExpiresAt: nil,
            planType: "pro",
            usageStatus: .coolingDown,
            sourceConfidence: 0.95,
            lastSyncedAt: now,
            rawExtractedStrings: []
        )

        let presentation = makeAccountRowPresentation(
            account: account,
            snapshot: snapshot,
            metadata: AccountMetadata(accountId: account.id),
            now: now
        )

        #expect(presentation.usageBars == [
            UsageBarPresentation(label: "S", remainingPercent: 0),
            UsageBarPresentation(label: "W", remainingPercent: 8)
        ])
    }

    @Test
    func accountRowPresentationAddsCooldownCountdownChip() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let account = Account(id: UUID(), provider: "Codex", email: "cooldown@example.com", label: nil)
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: nil,
            weeklyPercentUsed: nil,
            nextResetAt: now.addingTimeInterval(90 * 60),
            subscriptionExpiresAt: nil,
            usageStatus: .coolingDown,
            sourceConfidence: 1,
            lastSyncedAt: nil,
            rawExtractedStrings: []
        )

        let presentation = makeAccountRowPresentation(
            account: account,
            snapshot: snapshot,
            metadata: AccountMetadata(accountId: account.id),
            now: now
        )

        #expect(presentation.usageSummary?.text == "1h 30m")
        #expect(presentation.chips.map(\.text) == ["Codex", "Live", "Cooling down"])
        #expect(presentation.sourceChip?.text == "Live")
        #expect(presentation.statusChip?.text == "Cooling down")
        #expect(presentation.resetAccent?.title == "Session reset")
        #expect(presentation.resetAccent?.countdownText == "Resets in 1h 30m")
        #expect(presentation.resetAccent?.timeText == "18:16")
        #expect(presentation.resetAccent?.summaryText == "Session reset at 18:16 (in 1h 30m)")
    }

    @Test
    func countdownStringShowsLessThanMinuteForShortIntervals() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let target = now.addingTimeInterval(30)

        #expect(countdownString(until: target, now: now) == "<1m")
    }

    @Test
    func countdownStringUsesRussianShortUnits() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let target = now.addingTimeInterval((110 * 60 * 60) + (38 * 60))

        #expect(countdownString(until: target, now: now, language: .russian) == "110ч 38м")
    }

    @Test
    func accountRowPresentationKeepsCachedCountdownForStaleSnapshot() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let account = Account(id: UUID(), provider: "Codex", email: "stale@example.com", label: nil)
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: nil,
            weeklyPercentUsed: nil,
            nextResetAt: now.addingTimeInterval(90 * 60),
            subscriptionExpiresAt: nil,
            usageStatus: .stale,
            sourceConfidence: 1,
            lastSyncedAt: now.addingTimeInterval(-120),
            rawExtractedStrings: []
        )

        let presentation = makeAccountRowPresentation(
            account: account,
            snapshot: snapshot,
            metadata: AccountMetadata(accountId: account.id),
            now: now
        )

        #expect(presentation.usageSummary?.text == "1h 30m")
        #expect(presentation.chips.map(\.text) == ["Codex", "Stale"])
        #expect(presentation.sourceChip?.text == "Stale")
        #expect(presentation.statusChip == nil)
        #expect(presentation.resetAccent?.countdownText == "Resets in 1h 30m")
    }

    @Test
    func accountRowPresentationAddsResetAccentWhenResetIsSoon() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let account = Account(id: UUID(), provider: "Codex", email: "soon@example.com", label: nil)
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: 74,
            weeklyPercentUsed: 21,
            nextResetAt: now.addingTimeInterval(5 * 60 * 60),
            subscriptionExpiresAt: nil,
            usageStatus: .available,
            sourceConfidence: 1,
            lastSyncedAt: now,
            rawExtractedStrings: []
        )

        let presentation = makeAccountRowPresentation(
            account: account,
            snapshot: snapshot,
            metadata: AccountMetadata(accountId: account.id),
            now: now
        )

        #expect(presentation.usageSummary?.text == "S26 W79")
        #expect(presentation.resetAccent?.countdownText == "Resets in 5h")
        #expect(presentation.resetAccent?.timeText == "21:46")
    }

    @Test
    func accountRowPresentationLocalizesResetAccentCountdownForRussian() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let account = Account(id: UUID(), provider: "Codex", email: "ru@example.com", label: nil)
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: 74,
            weeklyPercentUsed: 21,
            nextResetAt: now.addingTimeInterval((5 * 60 * 60) + (30 * 60)),
            subscriptionExpiresAt: nil,
            usageStatus: .available,
            sourceConfidence: 1,
            lastSyncedAt: now,
            rawExtractedStrings: []
        )

        let presentation = makeAccountRowPresentation(
            account: account,
            snapshot: snapshot,
            metadata: AccountMetadata(accountId: account.id),
            now: now,
            language: .russian
        )

        #expect(presentation.usageSummary?.text == "S26 W79")
        #expect(presentation.resetAccent?.countdownText == "Сброс через 5ч 30м")
        #expect(presentation.resetAccent?.summaryText == "Сброс сессии в 22:16 (через 5ч 30м)")
    }

    @Test
    func accountRowPresentationKeepsFarFutureResetDetailsVisible() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let account = Account(id: UUID(), provider: "Codex", email: "future@example.com", label: nil)
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: 100,
            weeklyPercentUsed: 64,
            nextResetAt: now.addingTimeInterval(36 * 60 * 60),
            subscriptionExpiresAt: nil,
            usageStatus: .stale,
            sourceConfidence: 1,
            lastSyncedAt: now,
            rawExtractedStrings: []
        )

        let presentation = makeAccountRowPresentation(
            account: account,
            snapshot: snapshot,
            metadata: AccountMetadata(accountId: account.id),
            now: now
        )

        #expect(presentation.resetAccent?.countdownText == "Resets in 36h")
        #expect(presentation.resetAccent?.timeText == "04:46")
        #expect(presentation.resetAccent?.countdownTone == .orange)
    }

    @Test
    func accountRowPresentationShowsReadyAfterStoredResetPassed() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let account = Account(id: UUID(), provider: "Codex", email: "ready@example.com", label: nil)
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: 100,
            weeklyPercentUsed: 64,
            nextResetAt: now.addingTimeInterval(-90),
            subscriptionExpiresAt: nil,
            usageStatus: .stale,
            sourceConfidence: 1,
            lastSyncedAt: now.addingTimeInterval(-600),
            rawExtractedStrings: []
        )

        let presentation = makeAccountRowPresentation(
            account: account,
            snapshot: snapshot,
            metadata: AccountMetadata(accountId: account.id),
            now: now
        )

        #expect(presentation.resetAccent?.countdownText == "Ready")
        #expect(presentation.resetAccent?.countdownValue == "Ready")
        #expect(presentation.resetAccent?.timeText == "16:45")
        #expect(presentation.resetAccent?.summaryText == "Session reset at 16:45 (ready)")
        #expect(presentation.resetAccent?.countdownTone == .green)
    }

    @Test
    func accountRowPresentationUsesWeeklyResetAccentForWeeklyExhaustion() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let account = Account(id: UUID(), provider: "Codex", email: "weekly@example.com", label: nil)
        let weeklyResetAt = now.addingTimeInterval(26 * 60 * 60)
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: 35,
            weeklyPercentUsed: 100,
            nextResetAt: now.addingTimeInterval(2 * 60 * 60),
            weeklyResetAt: weeklyResetAt,
            subscriptionExpiresAt: nil,
            usageStatus: .exhausted,
            sourceConfidence: 1,
            lastSyncedAt: now.addingTimeInterval(-600),
            rawExtractedStrings: []
        )

        let presentation = makeAccountRowPresentation(
            account: account,
            snapshot: snapshot,
            metadata: AccountMetadata(accountId: account.id),
            now: now
        )

        #expect(presentation.usageSummary?.text == "26h 0m")
        #expect(presentation.resetAccent?.title == "Weekly reset")
        #expect(presentation.resetAccent?.countdownText == "Resets in 26h")
        #expect(presentation.resetAccent?.summaryText == "Weekly reset at 18:46 (in 26h)")
    }

    @Test
    func accountQuotaDisplayModeUsesWeeklyLockWhenWeekIsExhausted() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: UUID(),
            sessionPercentUsed: 35,
            weeklyPercentUsed: 100,
            nextResetAt: now.addingTimeInterval(2 * 60 * 60),
            weeklyResetAt: now.addingTimeInterval(26 * 60 * 60),
            subscriptionExpiresAt: nil,
            usageStatus: .exhausted,
            sourceConfidence: 1,
            lastSyncedAt: now,
            rawExtractedStrings: []
        )

        #expect(accountQuotaDisplayMode(snapshot: snapshot) == .weeklyLock)
        #expect(visibleUsageBars(snapshot: snapshot, usageBars: [
            UsageBarPresentation(label: "S", remainingPercent: 65),
            UsageBarPresentation(label: "W", remainingPercent: 0)
        ]) == [
            UsageBarPresentation(label: "W", remainingPercent: 0)
        ])
    }

    @Test
    func accountQuotaDisplayModeUsesSessionCooldownWhenOnlySessionIsExhausted() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: UUID(),
            sessionPercentUsed: 100,
            weeklyPercentUsed: 72,
            nextResetAt: now.addingTimeInterval(2 * 60 * 60),
            weeklyResetAt: now.addingTimeInterval(3 * 24 * 60 * 60),
            subscriptionExpiresAt: nil,
            usageStatus: .coolingDown,
            sourceConfidence: 1,
            lastSyncedAt: now,
            rawExtractedStrings: []
        )

        #expect(accountQuotaDisplayMode(snapshot: snapshot) == .sessionCooldown)
        #expect(visibleUsageBars(snapshot: snapshot, usageBars: [
            UsageBarPresentation(label: "S", remainingPercent: 0),
            UsageBarPresentation(label: "W", remainingPercent: 28)
        ], now: now) == [
            UsageBarPresentation(label: "S", remainingPercent: 0),
            UsageBarPresentation(label: "W", remainingPercent: 28)
        ])
    }

    @Test
    func accountQuotaDisplayModePrefersExpiredSubscriptionOverWeeklyReset() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: UUID(),
            sessionPercentUsed: 100,
            weeklyPercentUsed: 100,
            nextResetAt: now.addingTimeInterval(2 * 60 * 60),
            weeklyResetAt: now.addingTimeInterval(26 * 60 * 60),
            subscriptionExpiresAt: now.addingTimeInterval(-60),
            usageStatus: .exhausted,
            sourceConfidence: 1,
            lastSyncedAt: now,
            rawExtractedStrings: []
        )

        #expect(accountQuotaDisplayMode(snapshot: snapshot, now: now) == .subscriptionExpired)
        #expect(visibleUsageBars(snapshot: snapshot, usageBars: [
            UsageBarPresentation(label: "S", remainingPercent: 0),
            UsageBarPresentation(label: "W", remainingPercent: 0)
        ], now: now).isEmpty)
    }

    @Test
    func accountsListRowPresentationCarriesPriorityAndNotePreview() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let account = Account(id: UUID(), provider: "Codex", email: "list@example.com", label: nil)
        let metadata = AccountMetadata(accountId: account.id, priority: .backup, note: "Rotate after reset")
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: nil,
            weeklyPercentUsed: nil,
            nextResetAt: nil,
            subscriptionExpiresAt: now.addingTimeInterval(20 * 24 * 60 * 60),
            usageStatus: .exhausted,
            sourceConfidence: 1,
            lastSyncedAt: nil,
            rawExtractedStrings: []
        )

        let presentation = makeAccountsListRowPresentation(
            account: account,
            snapshot: snapshot,
            metadata: metadata,
            now: now
        )

        #expect(presentation.priorityChip?.text == "Backup")
        #expect(presentation.chips.map(\.text) == ["Codex", "Live", "Exhausted", "Expires Feb 1"])
        #expect(presentation.resetAccent == nil)
        #expect(presentation.notePreview == "Rotate after reset")
    }

    @Test
    func accountDetailPresentationBuildsSummaryAndIdentityRows() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let account = Account(id: UUID(), provider: "Codex", email: "detail@example.com", label: nil)
        let metadata = AccountMetadata(accountId: account.id, priority: .auxiliary, note: "")
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: nil,
            weeklyPercentUsed: nil,
            nextResetAt: now.addingTimeInterval(12 * 60 * 60),
            subscriptionExpiresAt: now.addingTimeInterval(12 * 60 * 60),
            usageStatus: .available,
            sourceConfidence: 1,
            lastSyncedAt: now.addingTimeInterval(-5),
            rawExtractedStrings: []
        )

        let presentation = makeAccountDetailPresentation(
            account: account,
            snapshot: snapshot,
            metadata: metadata,
            now: now
        )

        #expect(presentation.title == "detail@example.com")
        #expect(presentation.providerLine == "Provider: Codex")
        #expect(presentation.priorityChip?.text == "Auxiliary")
        #expect(presentation.summaryChips.map(\.text) == ["Live", "Available", "Expires Jan 13"])
        #expect(presentation.resetAccent?.countdownText == "Resets in 12h")
        #expect(presentation.resetAccent?.timeText == "04:46")
        #expect(presentation.resetAccent?.summaryText == "Session reset at 04:46 (in 12h)")
        #expect(presentation.identityRows.map(\.title) == ["Account", "Provider", "Subscription", "Last sync"])
        #expect(Array(presentation.identityRows.map(\.value).prefix(3)) == ["detail@example.com", "Codex", "Expires Jan 13"])
        #expect(presentation.noteFooter == "Optional note for renewal context, handoff, or reminders")
        #expect(presentation.noteCharacterCount == "0 characters")
    }

    @Test
    func accountRowPresentationTreatsClaudeProviderCaseInsensitively() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let account = Account(id: UUID(), provider: "claude", email: "claude@example.com", label: nil)
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: nil,
            weeklyPercentUsed: nil,
            nextResetAt: nil,
            subscriptionExpiresAt: nil,
            usageStatus: .available,
            sourceConfidence: 1,
            lastSyncedAt: now,
            rawExtractedStrings: [],
            totalTokensToday: 12_345,
            totalTokensThisWeek: 67_890
        )

        let presentation = makeAccountRowPresentation(
            account: account,
            snapshot: snapshot,
            metadata: AccountMetadata(accountId: account.id),
            now: now
        )

        #expect(presentation.syncText == "Today: 12K")
        #expect(presentation.totalTokensToday == 12_345)
        #expect(presentation.totalTokensThisWeek == 67_890)
    }

    @Test
    func accountRowPresentationDoesNotInferGoBadgeFromSubstring() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let account = Account(id: UUID(), provider: "Codex", email: "plan@example.com", label: nil)
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: 10,
            weeklyPercentUsed: 10,
            nextResetAt: nil,
            subscriptionExpiresAt: nil,
            planType: "cargo",
            usageStatus: .available,
            sourceConfidence: 1,
            lastSyncedAt: now,
            rawExtractedStrings: []
        )

        let presentation = makeAccountRowPresentation(
            account: account,
            snapshot: snapshot,
            metadata: AccountMetadata(accountId: account.id),
            now: now
        )

        #expect(presentation.planLabel == "Cargo")
    }

    @Test
    func accountRowPresentationMarksClaudeTokenOnlySnapshotAsLocalOnly() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let account = Account(id: UUID(), provider: "Claude", email: "local@example.com", label: nil)
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: nil,
            weeklyPercentUsed: nil,
            nextResetAt: nil,
            subscriptionExpiresAt: nil,
            usageStatus: .available,
            sourceConfidence: 1,
            lastSyncedAt: now,
            rawExtractedStrings: [],
            totalTokensToday: 4_200,
            totalTokensThisWeek: 12_000
        )

        let presentation = makeAccountRowPresentation(
            account: account,
            snapshot: snapshot,
            metadata: AccountMetadata(accountId: account.id),
            now: now
        )

        #expect(presentation.sourceChip?.text == "Local only")
        #expect(presentation.chips.map(\.text) == ["Claude", "Local only", "Available"])
    }

    @Test
    func accountRowPresentationMarksLowConfidenceSnapshotAsCached() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let account = Account(id: UUID(), provider: "Codex", email: "cached@example.com", label: nil)
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: account.id,
            sessionPercentUsed: 10,
            weeklyPercentUsed: 20,
            nextResetAt: nil,
            subscriptionExpiresAt: nil,
            usageStatus: .available,
            sourceConfidence: 0.4,
            lastSyncedAt: now,
            rawExtractedStrings: []
        )

        let presentation = makeAccountRowPresentation(
            account: account,
            snapshot: snapshot,
            metadata: AccountMetadata(accountId: account.id),
            now: now
        )

        #expect(presentation.sourceChip?.text == "Cached")
        #expect(presentation.chips.map(\.text) == ["Codex", "Cached", "Available"])
    }
}
