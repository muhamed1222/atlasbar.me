import Foundation

struct Provider: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: String
    let name: String

    private static let codexName = "Codex"
    private static let claudeName = "Claude"

    static let codex = Provider(name: Provider.codexName)
    static let claude = Provider(name: Provider.claudeName)

    init(name: String) {
        let normalized = Provider.canonicalName(for: name)
        self.id = normalized.lowercased()
        self.name = normalized
    }

    var isCodex: Bool {
        self == .codex
    }

    var isClaude: Bool {
        self == .claude
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = Provider(name: try container.decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(name)
    }

    private static func canonicalName(for raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.caseInsensitiveCompare(Self.codexName) == .orderedSame {
            return Self.codexName
        }
        if trimmed.caseInsensitiveCompare(Self.claudeName) == .orderedSame {
            return Self.claudeName
        }
        return trimmed.isEmpty ? Self.codexName : trimmed
    }
}

extension Provider: ExpressibleByStringLiteral {
    init(stringLiteral value: StringLiteralType) {
        self.init(name: value)
    }
}

extension Provider: CustomStringConvertible {
    var description: String {
        name
    }
}
