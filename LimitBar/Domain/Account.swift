import Foundation

struct Account: Identifiable, Codable, Equatable {
    let id: UUID
    var provider: String
    var email: String?
    var label: String?

    var displayName: String {
        email ?? label ?? "Unknown account"
    }
}
