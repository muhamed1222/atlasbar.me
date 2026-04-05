import Foundation
import OSLog

private let usageClientLogger = Logger(subsystem: "me.atlasbar.LimitBar", category: "CodexUsageClient")

protocol CodexUsageRequesting: Sendable {
    func fetchUsage(accessToken: String, accountId: String) async -> CodexUsageData?
}

struct CodexUsageClient {
    private static let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!

    func fetchUsage(accessToken: String, accountId: String) async -> CodexUsageData? {
        var request = URLRequest(url: Self.usageURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return nil }
            guard http.statusCode == 200 else {
                usageClientLogger.warning("Usage API status \(http.statusCode)")
                return nil
            }
            return parseUsageResponse(data)
        } catch {
            usageClientLogger.error("Usage API error: \(error)")
            return nil
        }
    }

    private func parseUsageResponse(_ data: Data) -> CodexUsageData? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rateLimit = json["rate_limit"] as? [String: Any] else {
            usageClientLogger.debug("Unexpected usage API response format")
            return nil
        }

        let primary = rateLimit["primary_window"] as? [String: Any]
        let secondary = rateLimit["secondary_window"] as? [String: Any]

        let sessionPct = primary?["used_percent"] as? Double
        let weeklyPct = secondary?["used_percent"] as? Double
        let resetTimestamp = primary?["reset_at"] as? TimeInterval
        let weeklyResetTimestamp = secondary?["reset_at"] as? TimeInterval
        let nextResetAt = resetTimestamp.map { Date(timeIntervalSince1970: $0) }
        let weeklyResetAt = weeklyResetTimestamp.map { Date(timeIntervalSince1970: $0) }

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
            weeklyResetAt: weeklyResetAt,
            status: status
        )
    }
}

extension CodexUsageClient: CodexUsageRequesting {}
