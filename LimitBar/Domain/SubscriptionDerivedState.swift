import Foundation

enum SubscriptionDerivedState: String, Codable, Equatable {
    case active
    case expiringSoon
    case expired
    case unknown

    static func from(expiryDate: Date?, now: Date = .now) -> SubscriptionDerivedState {
        guard let expiryDate else {
            return .unknown
        }
        if expiryDate < now {
            return .expired
        }
        if expiryDate.timeIntervalSince(now) <= 7 * 24 * 60 * 60 {
            return .expiringSoon
        }
        return .active
    }

    var displayLabel: String {
        switch self {
        case .active:
            return "Active"
        case .expiringSoon:
            return "Expires soon"
        case .expired:
            return "Expired"
        case .unknown:
            return "Unknown"
        }
    }
}
