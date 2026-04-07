import Foundation

struct Account: Identifiable, Codable, Equatable {
    let id: UUID
    var provider: Provider
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
        "\(provider.id)::\(normalizedIdentifier ?? "__unknown__")"
    }

    func matchesIdentity(provider: Provider, identifier: String?) -> Bool {
        guard self.provider == provider else {
            return false
        }

        let normalizedIdentifier = identifier?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return self.normalizedIdentifier == normalizedIdentifier
    }
}
