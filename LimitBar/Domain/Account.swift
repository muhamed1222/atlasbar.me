import Foundation

struct Account: Identifiable, Codable, Equatable {
    let id: UUID
    var provider: String
    var email: String?
    var label: String?
    var note: String?
    var priority: Int?

    var displayName: String {
        email ?? label ?? "Unknown account"
    }
}
