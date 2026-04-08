import CommonCrypto
import Foundation
import Security
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct ClaudeDesktopCookieReader: Sendable {
    private static let cacheTTL: TimeInterval = 30
    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var cachedCookieHeader: CachedCookieHeader?

    private struct CachedCookieHeader {
        let value: String?
        let expiresAt: Date
    }

    private static let safeStorageService = "Claude Safe Storage"
    private static let cookieNames = [
        "sessionKey",
        "cf_clearance",
        "lastActiveOrg",
        "__cf_bm",
        "__ssid",
        "routingHint"
    ]

    func cookieHeaderValue() -> String? {
        if let cached = Self.cachedCookieHeaderValue() {
            return cached
        }

        guard let passphrase = safeStoragePassphrase(),
              let cookies = readCookies(passphrase: passphrase),
              !cookies.isEmpty else {
            Self.storeCachedCookieHeader(nil)
            return nil
        }

        let ordered = Self.cookieNames.compactMap { name in
            cookies[name].map { "\(name)=\($0)" }
        }
        let header = ordered.isEmpty ? nil : ordered.joined(separator: "; ")
        Self.storeCachedCookieHeader(header)
        return header
    }

    private func safeStoragePassphrase() -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.safeStorageService,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return data
    }

    private static func cachedCookieHeaderValue(now: Date = .now) -> String?? {
        cacheLock.withLock {
            guard let cached = cachedCookieHeader,
                  cached.expiresAt > now else {
                cachedCookieHeader = nil
                return nil
            }
            return cached.value
        }
    }

    private static func storeCachedCookieHeader(_ value: String?, now: Date = .now) {
        cacheLock.withLock {
            cachedCookieHeader = CachedCookieHeader(
                value: value,
                expiresAt: now.addingTimeInterval(cacheTTL)
            )
        }
    }

    private func readCookies(passphrase: Data) -> [String: String]? {
        let databaseURL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent("Library/Application Support/Claude/Cookies", isDirectory: false)

        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            return nil
        }

        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let database else {
            sqlite3_close(database)
            return nil
        }
        defer { sqlite3_close(database) }

        let placeholders = Array(repeating: "?", count: Self.cookieNames.count).joined(separator: ",")
        let sql = """
            SELECT name, encrypted_value
            FROM cookies
            WHERE host_key IN ('.claude.ai', 'claude.ai')
              AND name IN (\(placeholders))
            ORDER BY last_access_utc DESC
            """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            sqlite3_finalize(statement)
            return nil
        }
        defer { sqlite3_finalize(statement) }

        for (index, name) in Self.cookieNames.enumerated() {
            sqlite3_bind_text(statement, Int32(index + 1), name, -1, sqliteTransient)
        }

        var cookies: [String: String] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let namePointer = sqlite3_column_text(statement, 0) else { continue }
            let name = String(cString: namePointer)
            guard cookies[name] == nil else { continue }

            let byteCount = sqlite3_column_bytes(statement, 1)
            guard byteCount > 0,
                  let blobPointer = sqlite3_column_blob(statement, 1) else { continue }

            let encrypted = Data(bytes: blobPointer, count: Int(byteCount))
            guard let value = decryptCookieValue(encrypted, passphrase: passphrase),
                  !value.isEmpty else {
                continue
            }
            cookies[name] = value
        }

        return cookies
    }

    private func decryptCookieValue(_ encrypted: Data, passphrase: Data) -> String? {
        let prefix = Data("v10".utf8)
        let payload = encrypted.starts(with: prefix) ? encrypted.dropFirst(prefix.count) : encrypted[...]

        let key = deriveKey(passphrase: passphrase)
        let iv = Data(repeating: 0x20, count: kCCBlockSizeAES128)
        guard let decrypted = aesCBCDecrypt(Data(payload), key: key, iv: iv) else {
            return nil
        }

        if decrypted.count > 32,
           let stripped = String(data: decrypted.dropFirst(32), encoding: .utf8),
           !stripped.isEmpty {
            return stripped
        }

        return String(data: decrypted, encoding: .utf8)
    }

    private func deriveKey(passphrase: Data) -> Data {
        let salt = Data("saltysalt".utf8)
        var derived = Data(repeating: 0, count: kCCKeySizeAES128)
        let derivedCount = derived.count
        let passphraseCount = passphrase.count
        let saltCount = salt.count

        _ = derived.withUnsafeMutableBytes { derivedBytes in
            passphrase.withUnsafeBytes { passphraseBytes in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passphraseBytes.bindMemory(to: Int8.self).baseAddress,
                        passphraseCount,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress,
                        saltCount,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
                        1003,
                        derivedBytes.bindMemory(to: UInt8.self).baseAddress,
                        derivedCount
                    )
                }
            }
        }

        return derived
    }

    private func aesCBCDecrypt(_ encrypted: Data, key: Data, iv: Data) -> Data? {
        var output = Data(repeating: 0, count: encrypted.count + kCCBlockSizeAES128)
        var decryptedLength: size_t = 0
        let keyCount = key.count
        let encryptedCount = encrypted.count
        let outputCount = output.count

        let status = output.withUnsafeMutableBytes { outputBytes in
            encrypted.withUnsafeBytes { encryptedBytes in
                key.withUnsafeBytes { keyBytes in
                    iv.withUnsafeBytes { ivBytes in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            keyCount,
                            ivBytes.baseAddress,
                            encryptedBytes.baseAddress,
                            encryptedCount,
                            outputBytes.baseAddress,
                            outputCount,
                            &decryptedLength
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else {
            return nil
        }

        output.removeSubrange(decryptedLength...)
        return output
    }
}
