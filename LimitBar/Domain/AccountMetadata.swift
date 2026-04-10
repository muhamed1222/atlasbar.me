import Foundation

struct AccountMetadata: Codable, Equatable {
    var accountId: UUID
    var priority: AccountPriority
    var note: String

    init(
        accountId: UUID,
        priority: AccountPriority = .none,
        note: String = ""
    ) {
        self.accountId = accountId
        self.priority = priority
        self.note = note
    }

    var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasNote: Bool {
        !trimmedNote.isEmpty
    }
}
