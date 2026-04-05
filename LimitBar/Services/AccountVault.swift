import Foundation
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

struct AccountVault: AccountVaulting {
    private static let legacyVaultDirectory = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".codex/accounts")
    private static let keychainService = "me.atlasbar.LimitBar.codex-auth-snapshot"

    func saveCurrentAuth(for email: String) throws {
        let data = try Data(contentsOf: CodexAuthReader.authPath)
        try saveToKeychain(data: data, email: email)
        logger.debug("Saved auth snapshot for \(email, privacy: .private)")
    }

    func hasSavedAuth(for email: String) -> Bool {
        if loadFromKeychain(email: email, allowsUserInteraction: false) != nil {
            return true
        }
        return FileManager.default.fileExists(
            atPath: Self.legacyVaultDirectory.appendingPathComponent(filename(for: email)).path
        )
    }

    func switchTo(email: String) throws {
        let data = try authData(for: email)
        try data.write(to: CodexAuthReader.authPath, options: .atomic)
        logger.info("Switched auth.json to \(email, privacy: .private)")
    }

    func activeEmail() -> String? {
        CodexAuthReader().readAccountInfo()?.email
    }

    private func filename(for email: String) -> String {
        let safe = email
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return "\(safe).json"
    }

    private func authData(for email: String) throws -> Data {
        if let data = loadFromKeychain(email: email, allowsUserInteraction: true) {
            return data
        }

        let legacyURL = Self.legacyVaultDirectory.appendingPathComponent(filename(for: email))
        guard FileManager.default.fileExists(atPath: legacyURL.path) else {
            throw AccountVaultError.notFound(email)
        }

        let data = try Data(contentsOf: legacyURL)
        try saveToKeychain(data: data, email: email)
        try? FileManager.default.removeItem(at: legacyURL)
        logger.notice("Migrated legacy auth snapshot for \(email, privacy: .private) into Keychain")
        return data
    }

    private func loadFromKeychain(email: String, allowsUserInteraction: Bool) -> Data? {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.keychainService,
            kSecAttrAccount: email,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        if !allowsUserInteraction {
            query[kSecUseAuthenticationUI] = kSecUseAuthenticationUIFail
        }

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    private func saveToKeychain(data: Data, email: String) throws {
        let baseQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.keychainService,
            kSecAttrAccount: email
        ]

        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData: data] as CFDictionary
        )

        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw AccountVaultError.keychainFailure(updateStatus)
        }

        var addQuery = baseQuery
        addQuery[kSecValueData] = data
        addQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw AccountVaultError.keychainFailure(addStatus)
        }
    }
}
