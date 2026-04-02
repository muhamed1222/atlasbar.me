import Foundation
import OSLog

private let tokenLogger = Logger(subsystem: "me.atlasbar.LimitBar", category: "CodexAccessTokenProvider")

protocol CodexAccessTokenProviding: Sendable {
    func currentAccessToken() async -> String?
}

struct CodexAccessTokenProvider {
    private static let tokenURL = URL(string: "https://auth.openai.com/oauth/token")!
    private static let clientId = "app_EMoamEEZ73f0CkXaXp7hrann"
    private let loadAuthData: @Sendable () throws -> Data
    private let writeAuthData: @Sendable (Data) throws -> Void
    private let sendRefreshRequest: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    init(
        loadAuthData: @escaping @Sendable () throws -> Data = {
            try Data(contentsOf: CodexAuthReader.authPath)
        },
        writeAuthData: @escaping @Sendable (Data) throws -> Void = { data in
            try data.write(to: CodexAuthReader.authPath, options: .atomic)
        },
        sendRefreshRequest: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse) = { request in
            try await URLSession.shared.data(for: request)
        }
    ) {
        self.loadAuthData = loadAuthData
        self.writeAuthData = writeAuthData
        self.sendRefreshRequest = sendRefreshRequest
    }

    func currentAccessToken() async -> String? {
        guard var token = readAccessToken() else {
            tokenLogger.debug("No access_token in auth.json")
            return nil
        }

        if isTokenExpired(token) {
            guard let refreshed = await refreshToken() else {
                tokenLogger.warning("Token expired and refresh failed")
                return nil
            }
            token = refreshed
        }

        return token
    }

    private func readAccessToken() -> String? {
        guard let json = loadAuthJSON(),
              let tokens = json["tokens"] as? [String: Any] else { return nil }
        return tokens["access_token"] as? String
    }

    private func loadAuthJSON() -> [String: Any]? {
        do {
            let data = try loadAuthData()
            return try JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch {
            tokenLogger.error("Failed to read auth.json: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    private func isTokenExpired(_ token: String) -> Bool {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else { return true }
        var base64 = parts[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let rem = base64.count % 4
        if rem > 0 { base64 += String(repeating: "=", count: 4 - rem) }
        guard let data = Data(base64Encoded: base64),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = payload["exp"] as? TimeInterval else { return true }
        return Date(timeIntervalSince1970: exp).timeIntervalSinceNow < 300
    }

    private func refreshToken() async -> String? {
        guard var json = loadAuthJSON(),
              var tokens = json["tokens"] as? [String: Any],
              let refreshToken = tokens["refresh_token"] as? String else { return nil }

        var request = URLRequest(url: Self.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": Self.clientId
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await sendRefreshRequest(request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let newAccessToken = result["access_token"] as? String else {
                tokenLogger.warning("Token refresh returned non-200 or bad body")
                return nil
            }
            if let v = result["access_token"] as? String { tokens["access_token"] = v }
            if let v = result["refresh_token"] as? String { tokens["refresh_token"] = v }
            if let v = result["id_token"] as? String { tokens["id_token"] = v }
            json["tokens"] = tokens
            persistAuthJSON(json)
            tokenLogger.info("Token refreshed successfully")
            return newAccessToken
        } catch {
            tokenLogger.error("Token refresh error: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    private func persistAuthJSON(_ json: [String: Any]) {
        guard let updated = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
            tokenLogger.warning("Token refresh succeeded, but updated auth.json could not be encoded")
            return
        }

        do {
            try writeAuthData(updated)
        } catch {
            tokenLogger.warning("Token refresh succeeded, but writing auth.json failed: \(String(describing: error), privacy: .public)")
        }
    }
}

extension CodexAccessTokenProvider: CodexAccessTokenProviding {}
