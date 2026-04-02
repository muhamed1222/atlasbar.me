import Foundation

struct CodexUsageData: Sendable {
    var sessionPercentUsed: Double?
    var weeklyPercentUsed: Double?
    var nextResetAt: Date?
    var status: UsageStatus
}

struct CurrentUsagePayload: Equatable, Sendable {
    var accountIdentifier: String?
    var planType: String?
    var subscriptionExpiresAt: Date?
    var sessionPercentUsed: Double?
    var weeklyPercentUsed: Double?
    var nextResetAt: Date?
    var usageStatus: UsageStatus
    var sourceConfidence: Double
    var rawExtractedStrings: [String]

    var hasUsageData: Bool {
        sessionPercentUsed != nil
            || weeklyPercentUsed != nil
            || nextResetAt != nil
            || usageStatus != .unknown
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
            usageStatus: usageStatus,
            sourceConfidence: sourceConfidence,
            rawExtractedStrings: rawExtractedStrings
        )
    }
}
