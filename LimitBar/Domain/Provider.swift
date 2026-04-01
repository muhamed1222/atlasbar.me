import Foundation

struct Provider: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String

    static let codex = Provider(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, name: "Codex")
}
