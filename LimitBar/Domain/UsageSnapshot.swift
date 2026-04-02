import Foundation
import SwiftUI

enum UsageStatus: String, Codable {
    case available
    case coolingDown
    case exhausted
    case unknown
    case stale

    func displayLabel(language: ResolvedAppLanguage = .english) -> String {
        AppStrings(language: language).statusLabel(self)
    }

    var color: Color {
        switch self {
        case .available:   return .green
        case .coolingDown: return .yellow
        case .exhausted:   return .red
        case .unknown:     return Color.secondary
        case .stale:       return Color.secondary
        }
    }
}

struct UsageSnapshot: Identifiable, Equatable {
    let id: UUID
    var accountId: UUID
    var sessionPercentUsed: Double?
    var weeklyPercentUsed: Double?
    var nextResetAt: Date?
    var subscriptionExpiresAt: Date?
    var planType: String? = nil
    var usageStatus: UsageStatus
    var sourceConfidence: Double
    var lastSyncedAt: Date?

    // Not persisted to disk — kept in memory only for debugging
    var rawExtractedStrings: [String]
}

// MARK: - Codable (rawExtractedStrings intentionally excluded)

extension UsageSnapshot: Codable {
    enum CodingKeys: String, CodingKey {
        case id, accountId
        case sessionPercentUsed, weeklyPercentUsed
        case nextResetAt, subscriptionExpiresAt
        case planType
        case usageStatus, subscriptionStatus
        case sourceConfidence, lastSyncedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                   = try c.decode(UUID.self,               forKey: .id)
        accountId            = try c.decode(UUID.self,               forKey: .accountId)
        sessionPercentUsed   = try c.decodeIfPresent(Double.self,    forKey: .sessionPercentUsed)
        weeklyPercentUsed    = try c.decodeIfPresent(Double.self,    forKey: .weeklyPercentUsed)
        nextResetAt          = try c.decodeIfPresent(Date.self,      forKey: .nextResetAt)
        subscriptionExpiresAt = try c.decodeIfPresent(Date.self,     forKey: .subscriptionExpiresAt)
        planType             = try c.decodeIfPresent(String.self,    forKey: .planType)
        usageStatus          = try c.decode(UsageStatus.self,        forKey: .usageStatus)
        _ = try c.decodeIfPresent(SubscriptionDerivedState.self,     forKey: .subscriptionStatus)
        sourceConfidence     = try c.decode(Double.self,             forKey: .sourceConfidence)
        lastSyncedAt         = try c.decodeIfPresent(Date.self,      forKey: .lastSyncedAt)
        rawExtractedStrings  = []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,                   forKey: .id)
        try c.encode(accountId,            forKey: .accountId)
        try c.encodeIfPresent(sessionPercentUsed,    forKey: .sessionPercentUsed)
        try c.encodeIfPresent(weeklyPercentUsed,     forKey: .weeklyPercentUsed)
        try c.encodeIfPresent(nextResetAt,           forKey: .nextResetAt)
        try c.encodeIfPresent(subscriptionExpiresAt, forKey: .subscriptionExpiresAt)
        try c.encodeIfPresent(planType,              forKey: .planType)
        try c.encode(usageStatus,          forKey: .usageStatus)
        try c.encode(sourceConfidence,     forKey: .sourceConfidence)
        try c.encodeIfPresent(lastSyncedAt,          forKey: .lastSyncedAt)
    }
}
