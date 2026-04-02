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
        #expect(presentation.usageSummary?.text == "S72 W60")
        #expect(presentation.chips.map(\.text) == ["Codex", "Available", "Expires 16 Jan"])
        #expect(presentation.chips.map(\.tone) == [.secondary, .green, .orange])
        #expect(presentation.usageBars == [
            UsageBarPresentation(label: "S", remainingPercent: 72),
            UsageBarPresentation(label: "W", remainingPercent: 60)
        ])
        #expect(presentation.notePreview == "Use for overflow")
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
        #expect(presentation.chips.map(\.text) == ["Codex", "Cooling down", "1h 30m"])
        #expect(presentation.chips.last?.monospaced == true)
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
        #expect(presentation.chips.map(\.text) == ["Codex", "Exhausted", "Expires 1 Feb"])
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
            nextResetAt: nil,
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
        #expect(presentation.summaryChips.map(\.text) == ["Available", "Expires 13 Jan"])
        #expect(presentation.identityRows.map(\.title) == ["Account", "Provider", "Subscription", "Last sync"])
        #expect(Array(presentation.identityRows.map(\.value).prefix(3)) == ["detail@example.com", "Codex", "Expires 13 Jan"])
        #expect(presentation.noteFooter == "Optional note for renewal context, handoff, or reminders")
        #expect(presentation.noteCharacterCount == "0 characters")
    }
}
