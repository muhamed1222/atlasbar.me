import Foundation
import Security

enum ClaudeSessionCookieStoreError: Error, LocalizedError {
    case emptyCookie
    case keychainFailure(OSStatus)

    var errorDescription: String? {
        switch self {
        case .emptyCookie:
            return "Claude session cookie is empty."
        case .keychainFailure(let status):
            return "Claude cookie Keychain operation failed with status \(status)"
        }
    }
}

protocol ClaudeSessionCookieStoring: Sendable {
    func hasStoredCookie() -> Bool
    func cookieHeaderValue() -> String?
    func saveCookie(_ rawValue: String) throws
    func clearCookie() throws
}

struct ClaudeSessionCookieStore: ClaudeSessionCookieStoring {
    private static let service = "me.atlasbar.LimitBar.claude-session-cookie"
    private static let account = "claude.ai-session-cookie"
    private let desktopCookieReader = ClaudeDesktopCookieReader()

    func hasStoredCookie() -> Bool {
        storedCookieHeaderValue()?.isEmpty == false
    }

    func cookieHeaderValue() -> String? {
        if let stored = storedCookieHeaderValue() {
            return stored
        }
        return desktopCookieReader.cookieHeaderValue()
    }

    private func storedCookieHeaderValue() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: Self.account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func saveCookie(_ rawValue: String) throws {
        let normalized = normalize(rawValue)
        guard !normalized.isEmpty else {
            throw ClaudeSessionCookieStoreError.emptyCookie
        }

        guard let data = normalized.data(using: .utf8) else {
            throw ClaudeSessionCookieStoreError.emptyCookie
        }

        let baseQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: Self.account
        ]

        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData: data] as CFDictionary
        )

        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw ClaudeSessionCookieStoreError.keychainFailure(updateStatus)
        }

        var addQuery = baseQuery
        addQuery[kSecValueData] = data
        addQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw ClaudeSessionCookieStoreError.keychainFailure(addStatus)
        }
    }

    func clearCookie() throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: Self.account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ClaudeSessionCookieStoreError.keychainFailure(status)
        }
    }

    private func normalize(_ rawValue: String) -> String {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.lowercased().hasPrefix("cookie:") {
            value = value.dropFirst("cookie:".count).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard !value.isEmpty else { return "" }

        if value.contains("=") {
            return value
        }

        return "sessionKey=\(value)"
    }
}
