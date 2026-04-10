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

    var normalizedAccountIdentifier: String? {
        let raw = accountIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw, !raw.isEmpty else { return nil }
        return raw.lowercased()
    }
}
