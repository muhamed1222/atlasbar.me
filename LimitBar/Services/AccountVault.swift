import Foundation
import LocalAuthentication
import Security
import OSLog

private let logger = Logger(subsystem: "me.atlasbar.LimitBar", category: "AccountVault")

enum AccountVaultError: Error, LocalizedError {
    case notFound(String)
    case keychainFailure(OSStatus)

    var errorDescription: String? {
        switch self {
        case .notFound(let email): return "No saved credentials for \(email)"
        case .keychainFailure(let status): return "Keychain operation failed with status \(status)"
        }
    }
}

protocol AccountVaulting: Sendable {
    func saveCurrentAuth(for email: String) throws
    func hasSavedAuth(for email: String) -> Bool
    func switchTo(email: String) throws
    func activeEmail() -> String?
}

struct StoredAuthVault: Codable, Equatable {
    var entries: [String: Data] = [:]

    func authData(for email: String) -> Data? {
        entries[Self.normalizedKey(for: email)]
    }

    mutating func setAuthData(_ data: Data, for email: String) {
        entries[Self.normalizedKey(for: email)] = data
    }

    static func normalizedKey(for email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

struct AccountVault: AccountVaulting {
    private static let fileVaultDirectory = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".codex/accounts")
    private static let keychainService = "me.atlasbar.LimitBar.codex-auth-snapshot"
    private static let consolidatedAccount = "__limitbar_vault__"

    func saveCurrentAuth(for email: String) throws {
        let data = try Data(contentsOf: CodexAuthReader.authPath)
        try saveFileSnapshot(data, for: email)
        logger.debug("Saved auth snapshot for \(email, privacy: .private)")
    }

    func hasSavedAuth(for email: String) -> Bool {
        loadFileSnapshot(email: email) != nil
    }

    func switchTo(email: String) throws {
        let data = try authData(for: email)
        try data.write(to: CodexAuthReader.authPath, options: .atomic)
        logger.info("Switched auth.json to \(email, privacy: .private)")
    }

    func activeEmail() -> String? {
        CodexAuthReader().readAccountInfo()?.email
    }

    private func normalizedFilename(for email: String) -> String {
        let safe = StoredAuthVault.normalizedKey(for: email)
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return "\(safe).json"
    }

    private func legacyFilename(for email: String) -> String {
        let safe = email
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return "\(safe).json"
    }

    private func authData(for email: String) throws -> Data {
        if let data = loadFileSnapshot(email: email) {
            return data
        }

        let migratedVault = try migrateKeychainSnapshotsToFiles(allowsUserInteraction: true)
        if let migrated = migratedVault.authData(for: email) {
            return migrated
        }

        throw AccountVaultError.notFound(email)
    }

    private func loadConsolidatedVault(allowsUserInteraction: Bool) -> StoredAuthVault? {
        guard let data = loadKeychainItem(
            account: Self.consolidatedAccount,
            allowsUserInteraction: allowsUserInteraction
        ) else {
            return nil
        }
        return try? JSONDecoder().decode(StoredAuthVault.self, from: data)
    }

    private func loadFileSnapshot(email: String) -> Data? {
        let normalizedURL = Self.fileVaultDirectory.appendingPathComponent(normalizedFilename(for: email))
        if let data = try? Data(contentsOf: normalizedURL) {
            return data
        }

        let legacyURL = Self.fileVaultDirectory.appendingPathComponent(legacyFilename(for: email))
        guard legacyURL != normalizedURL else {
            return nil
        }
        return try? Data(contentsOf: legacyURL)
    }

    private func saveFileSnapshot(_ data: Data, for email: String) throws {
        try FileManager.default.createDirectory(
            at: Self.fileVaultDirectory,
            withIntermediateDirectories: true
        )

        let normalizedURL = Self.fileVaultDirectory.appendingPathComponent(normalizedFilename(for: email))
        if let existing = try? Data(contentsOf: normalizedURL), existing == data {
            return
        }

        try data.write(to: normalizedURL, options: .atomic)

        let legacyURL = Self.fileVaultDirectory.appendingPathComponent(legacyFilename(for: email))
        if legacyURL != normalizedURL, FileManager.default.fileExists(atPath: legacyURL.path) {
            try? FileManager.default.removeItem(at: legacyURL)
        }
    }

    private func migrateKeychainSnapshotsToFiles(allowsUserInteraction: Bool) throws -> StoredAuthVault {
        var migratedVault = StoredAuthVault()

        if let consolidatedVault = loadConsolidatedVault(allowsUserInteraction: allowsUserInteraction) {
            for (email, data) in consolidatedVault.entries {
                try saveFileSnapshot(data, for: email)
                migratedVault.entries[email] = data
            }
            deleteKeychainItem(account: Self.consolidatedAccount)
            logger.notice("Migrated consolidated keychain auth vault into file snapshots")
        }

        let legacyEntries = loadAllLegacyItemsFromKeychain(allowsUserInteraction: allowsUserInteraction)
        if !legacyEntries.isEmpty {
            for (email, data) in legacyEntries {
                try saveFileSnapshot(data, for: email)
                migratedVault.setAuthData(data, for: email)
            }
            deleteLegacyKeychainItems(for: Array(legacyEntries.keys))
            logger.notice("Migrated legacy keychain auth snapshots into file snapshots")
        }

        return migratedVault
    }

    private func loadKeychainItem(account: String, allowsUserInteraction: Bool) -> Data? {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.keychainService,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        if !allowsUserInteraction {
            query[kSecUseAuthenticationContext] = authenticationContext(interactionAllowed: false)
        }

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    private func loadAllLegacyItemsFromKeychain(allowsUserInteraction: Bool) -> [String: Data] {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.keychainService,
            kSecReturnAttributes: true,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitAll
        ]

        if !allowsUserInteraction {
            query[kSecUseAuthenticationContext] = authenticationContext(interactionAllowed: false)
        }

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let results = item as? [[AnyHashable: Any]] else {
            return [:]
        }

        var entries: [String: Data] = [:]
        for result in results {
            guard let account = result[kSecAttrAccount] as? String,
                  account != Self.consolidatedAccount,
                  let data = result[kSecValueData] as? Data else {
                continue
            }
            entries[account] = data
        }
        return entries
    }

    private func deleteLegacyKeychainItems(for emails: [String]) {
        for email in emails {
            deleteKeychainItem(account: email)
        }
    }

    private func deleteKeychainItem(account: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.keychainService,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func authenticationContext(interactionAllowed: Bool) -> LAContext {
        let context = LAContext()
        context.interactionNotAllowed = !interactionAllowed
        return context
    }
}
