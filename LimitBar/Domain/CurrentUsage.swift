import Foundation

struct CodexUsageData: Sendable {
    var sessionPercentUsed: Double?
    var weeklyPercentUsed: Double?
    var nextResetAt: Date?
    var weeklyResetAt: Date? = nil
    var status: UsageStatus
}

struct CurrentUsagePayload: Equatable, Sendable {
    var accountIdentifier: String?
    var planType: String?
    var subscriptionExpiresAt: Date?
    var sessionPercentUsed: Double?
    var weeklyPercentUsed: Double?
    var nextResetAt: Date?
    var weeklyResetAt: Date? = nil
    var usageStatus: UsageStatus
    var sourceConfidence: Double
    var rawExtractedStrings: [String]
    var provider: Provider = .codex
    var totalTokensToday: Int? = nil
    var totalTokensThisWeek: Int? = nil

    var hasUsageData: Bool {
        sessionPercentUsed != nil
            || weeklyPercentUsed != nil
            || nextResetAt != nil
            || weeklyResetAt != nil
            || usageStatus != .unknown
    }

    var normalizedAccountIdentifier: String? {
        let raw = accountIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw, !raw.isEmpty else { return nil }
        return raw.lowercased()
    }

    var identityKey: String {
        "\(provider.id)::\(normalizedAccountIdentifier ?? "__unknown__")"
    }

    func mergingMetadata(from primary: CurrentUsagePayload?) -> CurrentUsagePayload {
        guard let primary else { return self }
        return CurrentUsagePayload(
            accountIdentifier: primary.accountIdentifier ?? accountIdentifier,
            planType: primary.planType ?? planType,
            subscriptionExpiresAt: primary.subscriptionExpiresAt ?? subscriptionExpiresAt,
            sessionPercentUsed: sessionPercentUsed,
            weeklyPercentUsed: weeklyPercentUsed,
            nextResetAt: nextResetAt,
            weeklyResetAt: weeklyResetAt,
            usageStatus: usageStatus,
            sourceConfidence: sourceConfidence,
            rawExtractedStrings: rawExtractedStrings,
            provider: provider,
            totalTokensToday: totalTokensToday,
            totalTokensThisWeek: totalTokensThisWeek
        )
    }
}
