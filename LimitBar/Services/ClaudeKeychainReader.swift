import Foundation
import Security
import OSLog

private let logger = Logger(subsystem: "me.atlasbar.LimitBar", category: "ClaudeKeychainReader")

struct ClaudeCredentials: Sendable {
    var subscriptionType: String?
    var accountIdentifier: String
    var organizationUUID: String?
}

protocol ClaudeCredentialsReading: Sendable {
    func readCredentials() -> ClaudeCredentials?
}

struct ClaudeKeychainReader: ClaudeCredentialsReading {
    private static let cacheTTL: TimeInterval = 30
    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var credentialsCache: CachedCredentials?

    private struct CachedCredentials {
        let value: ClaudeCredentials?
        let expiresAt: Date
    }

    private struct ClaudeSessionProfile: Decodable {
        var accountName: String?
        var emailAddress: String?
        var lastActivityAt: Int?

        var hasIdentity: Bool {
            let trimmedEmail = emailAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedName = accountName?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (trimmedEmail?.isEmpty == false) || (trimmedName?.isEmpty == false)
        }
    }

    func readCredentials() -> ClaudeCredentials? {
        if let cached = Self.cachedCredentials() {
            return cached.value
        }

        let credentials = readCredentialsFromKeychain()
        Self.storeCachedCredentials(credentials)
        return credentials
    }

    private func readCredentialsFromKeychain() -> ClaudeCredentials? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "Claude Code-credentials",
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any] else {
            logger.debug("No Claude Code credentials found in Keychain (status: \(status))")
            return nil
        }

        let subscriptionType = oauth["subscriptionType"] as? String
        let organizationUUID = json["organizationUuid"] as? String
        let profile = latestSessionProfile()
        let identifier = profile?.emailAddress
            ?? profile?.accountName
            ?? subscriptionType.map { "Claude \($0.capitalized)" }
            ?? "Claude Code"

        return ClaudeCredentials(
            subscriptionType: subscriptionType,
            accountIdentifier: identifier,
            organizationUUID: organizationUUID
        )
    }

    private static func cachedCredentials(now: Date = .now) -> CachedCredentials? {
        cacheLock.withLock {
            guard let cached = credentialsCache,
                  cached.expiresAt > now else {
                credentialsCache = nil
                return nil
            }
            return cached
        }
    }

    private static func storeCachedCredentials(_ credentials: ClaudeCredentials?, now: Date = .now) {
        cacheLock.withLock {
            credentialsCache = CachedCredentials(
                value: credentials,
                expiresAt: now.addingTimeInterval(cacheTTL)
            )
        }
    }

    private func latestSessionProfile() -> ClaudeSessionProfile? {
        let roots = [
            URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Application Support/Claude/local-agent-mode-sessions"),
            URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Application Support/Claude/claude-code-sessions")
        ]

        let candidateURLs = roots.flatMap(sessionFileURLs(in:))

        let profiles = candidateURLs.compactMap { url -> (ClaudeSessionProfile, Int, Date)? in
            guard let data = try? Data(contentsOf: url),
                  let profile = try? JSONDecoder().decode(ClaudeSessionProfile.self, from: data),
                  profile.hasIdentity else {
                return nil
            }

            let modifiedAt = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return (profile, profile.lastActivityAt ?? 0, modifiedAt)
        }

        return profiles.max { lhs, rhs in
            if lhs.1 == rhs.1 {
                return lhs.2 < rhs.2
            }
            return lhs.1 < rhs.1
        }?.0
    }

    private func sessionFileURLs(in root: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var result: [URL] = []
        for case let fileURL as URL in enumerator {
            guard fileURL.lastPathComponent.hasPrefix("local_"),
                  fileURL.pathExtension == "json" else {
                continue
            }
            let isRegularFile = (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile ?? false
            if isRegularFile {
                result.append(fileURL)
            }
        }
        return result
    }
}
