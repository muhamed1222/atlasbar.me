import Foundation
import Security
import OSLog

private let logger = Logger(subsystem: "me.atlasbar.LimitBar", category: "ClaudeKeychainReader")

enum KeychainSecurityCLIReader {
    static func password(service: String, timeout: TimeInterval = 2) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", service, "-w"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            return nil
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
        }

        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
            return nil
        }

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        _ = errorPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            return nil
        }

        let value = String(data: output, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }
}

struct ClaudeCredentials: Sendable {
    var subscriptionType: String?
    var accountIdentifier: String
    var organizationUUID: String?
}

protocol ClaudeCredentialsReading: Sendable {
    func readCredentials() -> ClaudeCredentials?
}

struct ClaudeKeychainReader: ClaudeCredentialsReading {
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
        if let credentials = readCredentialsViaSecurityCLI() {
            return credentials
        }

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

    private func readCredentialsViaSecurityCLI() -> ClaudeCredentials? {
        guard let rawJSON = KeychainSecurityCLIReader.password(service: "Claude Code-credentials"),
              let data = rawJSON.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any] else {
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
