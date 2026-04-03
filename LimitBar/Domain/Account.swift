import Foundation

struct Account: Identifiable, Codable, Equatable {
    let id: UUID
    var provider: String
    var email: String?
    var label: String?

    var displayName: String {
        email ?? label ?? "Unknown account"
    }

    var normalizedIdentifier: String? {
        let raw = (email ?? label)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw, !raw.isEmpty else { return nil }
        return raw.lowercased()
    }

    var identityKey: String {
        let providerKey = provider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(providerKey)::\(normalizedIdentifier ?? "__unknown__")"
    }

    func matchesIdentity(provider: String, identifier: String?) -> Bool {
        let providerKey = provider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard self.provider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == providerKey else {
            return false
        }

        let normalizedIdentifier = identifier?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return self.normalizedIdentifier == normalizedIdentifier
    }
}
