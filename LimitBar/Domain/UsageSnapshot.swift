import Foundation

enum UsageStatus: String, Codable {
    case available
    case coolingDown
    case exhausted
    case unknown
    case stale

    func displayLabel(language: ResolvedAppLanguage = .english) -> String {
        AppStrings(language: language).statusLabel(self)
    }
}

enum SnapshotStateOrigin: String, Codable {
    case server
    case predictedReset
}

struct UsageSnapshot: Identifiable, Equatable {
    let id: UUID
    var accountId: UUID
    var sessionPercentUsed: Double?
    var weeklyPercentUsed: Double?
    var nextResetAt: Date?
    var weeklyResetAt: Date? = nil
    var subscriptionExpiresAt: Date?
    var planType: String? = nil
    var usageStatus: UsageStatus
    var stateOrigin: SnapshotStateOrigin = .server
    var sourceConfidence: Double
    var lastSyncedAt: Date?

    // Not persisted to disk — kept in memory only for debugging
    var rawExtractedStrings: [String]

    var totalTokensToday: Int? = nil
    var totalTokensThisWeek: Int? = nil
}

// MARK: - Codable (rawExtractedStrings intentionally excluded)

extension UsageSnapshot: Codable {
    enum CodingKeys: String, CodingKey {
    case id, accountId
    case sessionPercentUsed, weeklyPercentUsed
    case nextResetAt, weeklyResetAt, subscriptionExpiresAt
    case planType
    case usageStatus, subscriptionStatus
        case stateOrigin
        case sourceConfidence, lastSyncedAt
        case totalTokensToday, totalTokensThisWeek
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                   = try c.decode(UUID.self,               forKey: .id)
        accountId            = try c.decode(UUID.self,               forKey: .accountId)
        sessionPercentUsed   = try c.decodeIfPresent(Double.self,    forKey: .sessionPercentUsed)
        weeklyPercentUsed    = try c.decodeIfPresent(Double.self,    forKey: .weeklyPercentUsed)
        nextResetAt          = try c.decodeIfPresent(Date.self,      forKey: .nextResetAt)
        weeklyResetAt        = try c.decodeIfPresent(Date.self,      forKey: .weeklyResetAt)
        subscriptionExpiresAt = try c.decodeIfPresent(Date.self,     forKey: .subscriptionExpiresAt)
        planType             = try c.decodeIfPresent(String.self,    forKey: .planType)
        usageStatus          = try c.decode(UsageStatus.self,        forKey: .usageStatus)
        let decodedStateOrigin = try c.decodeIfPresent(String.self, forKey: .stateOrigin)
        stateOrigin = SnapshotStateOrigin(rawValue: decodedStateOrigin ?? "") ?? .server
        _ = try c.decodeIfPresent(SubscriptionDerivedState.self,     forKey: .subscriptionStatus)
        sourceConfidence     = try c.decode(Double.self,             forKey: .sourceConfidence)
        lastSyncedAt         = try c.decodeIfPresent(Date.self,      forKey: .lastSyncedAt)
        totalTokensToday     = try c.decodeIfPresent(Int.self,       forKey: .totalTokensToday)
        totalTokensThisWeek  = try c.decodeIfPresent(Int.self,       forKey: .totalTokensThisWeek)
        rawExtractedStrings  = []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,                   forKey: .id)
        try c.encode(accountId,            forKey: .accountId)
        try c.encodeIfPresent(sessionPercentUsed,    forKey: .sessionPercentUsed)
        try c.encodeIfPresent(weeklyPercentUsed,     forKey: .weeklyPercentUsed)
        try c.encodeIfPresent(nextResetAt,           forKey: .nextResetAt)
        try c.encodeIfPresent(weeklyResetAt,         forKey: .weeklyResetAt)
        try c.encodeIfPresent(subscriptionExpiresAt, forKey: .subscriptionExpiresAt)
        try c.encodeIfPresent(planType,              forKey: .planType)
        try c.encode(usageStatus,          forKey: .usageStatus)
        try c.encode(stateOrigin,          forKey: .stateOrigin)
        try c.encode(sourceConfidence,     forKey: .sourceConfidence)
        try c.encodeIfPresent(lastSyncedAt,          forKey: .lastSyncedAt)
        try c.encodeIfPresent(totalTokensToday,      forKey: .totalTokensToday)
        try c.encodeIfPresent(totalTokensThisWeek,   forKey: .totalTokensThisWeek)
    }
}
