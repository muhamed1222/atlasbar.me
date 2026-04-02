import Foundation

struct AccountMetadata: Codable, Equatable {
    var accountId: UUID
    var priority: AccountPriority
    var note: String
    var updatedAt: Date

    init(
        accountId: UUID,
        priority: AccountPriority = .none,
        note: String = "",
        updatedAt: Date = .now
    ) {
        self.accountId = accountId
        self.priority = priority
        self.note = note
        self.updatedAt = updatedAt
    }

    var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasNote: Bool {
        !trimmedNote.isEmpty
    }
}
