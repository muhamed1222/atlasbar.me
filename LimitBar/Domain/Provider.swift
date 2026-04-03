import Foundation

struct Provider: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String

    static let codex = Provider(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, name: "Codex")
    static let claude = Provider(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "Claude")
}
