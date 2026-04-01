import Foundation
import OSLog

private let logger = Logger(subsystem: "me.atlasbar.LimitBar", category: "CodexUsageAPI")

struct CodexUsageData {
    var sessionPercentUsed: Double?
    var weeklyPercentUsed: Double?
    var nextResetAt: Date?
    var status: UsageStatus
}

struct CodexUsageAPI {
    private static let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    private static let tokenURL = URL(string: "https://auth.openai.com/oauth/token")!
    private static let clientId = "app_EMoamEEZ73f0CkXaXp7hrann"

    func fetchUsage(authInfo: CodexAccountInfo) async -> CodexUsageData? {
        guard var token = readAccessToken() else {
            logger.debug("No access_token in auth.json")
            return nil
        }

        if isTokenExpired(token) {
            guard let refreshed = await refreshToken() else {
                logger.warning("Token expired and refresh failed")
                return nil
            }
            token = refreshed
        }

        guard let accountId = authInfo.accountId else {
            logger.debug("No account_id in auth.json")
            return nil
        }

        var request = URLRequest(url: Self.usageURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return nil }
            guard http.statusCode == 200 else {
                logger.warning("Usage API status \(http.statusCode)")
                return nil
            }
            return parseUsageResponse(data)
        } catch {
            logger.error("Usage API error: \(error)")
            return nil
        }
    }

    // MARK: - Token helpers

    private func readAccessToken() -> String? {
        guard let data = try? Data(contentsOf: CodexAuthReader.authPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = json["tokens"] as? [String: Any] else { return nil }
        return tokens["access_token"] as? String
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
        // Refresh if less than 5 minutes remaining
        return Date(timeIntervalSince1970: exp).timeIntervalSinceNow < 300
    }

    private func refreshToken() async -> String? {
        guard let fileData = try? Data(contentsOf: CodexAuthReader.authPath),
              var json = try? JSONSerialization.jsonObject(with: fileData) as? [String: Any],
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
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let newAccessToken = result["access_token"] as? String else {
                logger.warning("Token refresh returned non-200 or bad body")
                return nil
            }
            // Persist updated tokens
            if let v = result["access_token"] as? String { tokens["access_token"] = v }
            if let v = result["refresh_token"] as? String { tokens["refresh_token"] = v }
            if let v = result["id_token"] as? String { tokens["id_token"] = v }
            json["tokens"] = tokens
            if let updated = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
                try? updated.write(to: CodexAuthReader.authPath)
            }
            logger.info("Token refreshed successfully")
            return newAccessToken
        } catch {
            logger.error("Token refresh error: \(error)")
            return nil
        }
    }

    // MARK: - Response parsing

    private func parseUsageResponse(_ data: Data) -> CodexUsageData? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rateLimit = json["rate_limit"] as? [String: Any] else {
            logger.debug("Unexpected usage API response format")
            return nil
        }

        let primary = rateLimit["primary_window"] as? [String: Any]
        let secondary = rateLimit["secondary_window"] as? [String: Any]

        let sessionPct = primary?["used_percent"] as? Double
        let weeklyPct = secondary?["used_percent"] as? Double
        let resetTimestamp = primary?["reset_at"] as? TimeInterval
        let nextResetAt = resetTimestamp.map { Date(timeIntervalSince1970: $0) }

        let status: UsageStatus
        if let pct = sessionPct {
            if pct >= 100 { status = .exhausted }
            else if pct >= 80 { status = .coolingDown }
            else { status = .available }
        } else {
            status = .unknown
        }

        return CodexUsageData(
            sessionPercentUsed: sessionPct,
            weeklyPercentUsed: weeklyPct,
            nextResetAt: nextResetAt,
            status: status
        )
    }
}
