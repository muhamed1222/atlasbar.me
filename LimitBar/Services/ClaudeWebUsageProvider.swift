import Foundation
import OSLog

private let logger = Logger(subsystem: "me.atlasbar.LimitBar", category: "ClaudeWebUsageProvider")

struct ClaudeWebUsageProvider: CurrentUsageProviding {
    typealias RequestPerformer = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private let credentialsReader: any ClaudeCredentialsReading
    private let cookieStore: any ClaudeSessionCookieStoring
    private let performRequest: RequestPerformer

    init(
        credentialsReader: any ClaudeCredentialsReading = ClaudeKeychainReader(),
        cookieStore: any ClaudeSessionCookieStoring,
        performRequest: @escaping RequestPerformer = { request in
            try await URLSession.shared.data(for: request)
        }
    ) {
        self.credentialsReader = credentialsReader
        self.cookieStore = cookieStore
        self.performRequest = performRequest
    }

    func fetchCurrentUsage() async -> CurrentUsagePayload? {
        guard let credentials = credentialsReader.readCredentials(),
              let organizationUUID = credentials.organizationUUID,
              let cookieHeader = cookieStore.cookieHeaderValue() else {
            return nil
        }

        guard let url = URL(string: "https://claude.ai/api/organizations/\(organizationUUID)/usage") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue("https://claude.ai/settings/usage", forHTTPHeaderField: "Referer")
        request.setValue("https://claude.ai", forHTTPHeaderField: "Origin")

        do {
            let (data, response) = try await performRequest(request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                if let httpResponse = response as? HTTPURLResponse {
                    logger.warning("Claude usage API returned HTTP \(httpResponse.statusCode)")
                }
                return nil
            }

            let payload = try JSONDecoder.claudeUsageDecoder.decode(ClaudeUsageResponse.self, from: data)
            return CurrentUsagePayload(
                accountIdentifier: credentials.accountIdentifier,
                planType: credentials.subscriptionType,
                subscriptionExpiresAt: nil,
                sessionPercentUsed: payload.fiveHour?.percentUsed,
                weeklyPercentUsed: payload.sevenDay?.percentUsed,
                nextResetAt: payload.fiveHour?.resetAt ?? payload.sevenDay?.resetAt,
                weeklyResetAt: payload.sevenDay?.resetAt,
                usageStatus: payload.usageStatus,
                sourceConfidence: 0.95,
                rawExtractedStrings: [],
                provider: "Claude",
                totalTokensToday: nil,
                totalTokensThisWeek: nil
            )
        } catch {
            logger.warning("Failed to decode Claude usage response: \(error)")
            return nil
        }
    }
}

func decodeUsagePayload(from rawBody: String) -> ClaudeUsageResponse? {
    guard let data = rawBody.data(using: .utf8) else { return nil }
    return try? JSONDecoder.claudeUsageDecoder.decode(ClaudeUsageResponse.self, from: data)
}

struct ClaudeUsageResponse: Decodable {
    struct UsageWindow: Decodable {
        let remainingPercent: Double?
        let usedPercent: Double?
        let resetAt: Date?

        enum CodingKeys: String, CodingKey {
            case remainingPercent = "remaining_percent"
            case usedPercent = "used_percent"
            case resetAt = "reset_at"
        }

        var percentUsed: Double? {
            if let usedPercent {
                return usedPercent
            }
            if let remainingPercent {
                return max(0, min(100, 100 - remainingPercent))
            }
            return nil
        }
    }

    let fiveHour: UsageWindow?
    let sevenDay: UsageWindow?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }

    var usageStatus: UsageStatus {
        let remainingSession = fiveHour?.remainingPercent
        let remainingWeek = sevenDay?.remainingPercent
        let remaining = [remainingSession, remainingWeek].compactMap { $0 }

        guard !remaining.isEmpty else {
            return .unknown
        }
        if remaining.contains(where: { $0 <= 0 }) {
            return .coolingDown
        }
        return .available
    }
}

extension JSONDecoder {
    static let claudeUsageDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = parseClaudeISO8601Date(value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date: \(value)")
        }
        return decoder
    }()
}

func parseClaudeISO8601Date(_ value: String) -> Date? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractional.date(from: value) {
        return date
    }

    let basic = ISO8601DateFormatter()
    return basic.date(from: value)
}
