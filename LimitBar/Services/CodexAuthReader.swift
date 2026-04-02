import Foundation
import OSLog

private let logger = Logger(subsystem: "me.atlasbar.LimitBar", category: "CodexAuthReader")

struct CodexAccountInfo: Equatable, Sendable {
    var email: String?
    var planType: String?
    var subscriptionExpiresAt: Date?
    var accountId: String?
    var userId: String?
}

protocol CodexAuthReading: Sendable {
    func readAccountInfo() -> CodexAccountInfo?
}

struct CodexAuthReader {
    static let authPath = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".codex/auth.json")

    func readAccountInfo() -> CodexAccountInfo? {
        guard let data = try? Data(contentsOf: Self.authPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = json["tokens"] as? [String: Any] else {
            logger.debug("No .codex/auth.json found or invalid format")
            return nil
        }

        let accountId = tokens["account_id"] as? String

        // Prefer id_token which has richer claims including email and subscription
        let jwt = (tokens["id_token"] as? String) ?? (tokens["access_token"] as? String)
        guard let jwt else { return nil }

        guard let payload = decodeJWTPayload(jwt) else { return nil }

        let email = payload["email"] as? String

        // Subscription info lives in the OpenAI auth namespace
        let openaiAuth = payload["https://api.openai.com/auth"] as? [String: Any]
        let planType = openaiAuth?["chatgpt_plan_type"] as? String
        let expiryString = openaiAuth?["chatgpt_subscription_active_until"] as? String
        let userId = openaiAuth?["chatgpt_user_id"] as? String

        let subscriptionExpiresAt = expiryString.flatMap { parseISO8601($0) }

        return CodexAccountInfo(
            email: email,
            planType: planType,
            subscriptionExpiresAt: subscriptionExpiresAt,
            accountId: accountId,
            userId: userId
        )
    }

    // MARK: - Private

    private func decodeJWTPayload(_ token: String) -> [String: Any]? {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else { return nil }

        var base64 = parts[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // Pad to multiple of 4
        let remainder = base64.count % 4
        if remainder > 0 { base64 += String(repeating: "=", count: 4 - remainder) }

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }

    private func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
            ?? ISO8601DateFormatter().date(from: string)
    }
}

extension CodexAuthReader: CodexAuthReading {}
