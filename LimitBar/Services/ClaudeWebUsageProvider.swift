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

        guard let url = Self.claudeURL(path: "/api/organizations/\(organizationUUID)/usage") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue("https://claude.ai/settings/usage", forHTTPHeaderField: "Referer")
        request.setValue("https://claude.ai", forHTTPHeaderField: "Origin")

        do {
            async let usageRequest = fetchWithRetry(request)
            async let subscriptionRequest = fetchSubscriptionDetails(
                organizationUUID: organizationUUID,
                cookieHeader: cookieHeader
            )

            let (data, response) = try await usageRequest
            let subscription = await subscriptionRequest
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
                subscriptionExpiresAt: subscription?.nextChargeDate,
                sessionPercentUsed: payload.fiveHour?.percentUsed,
                weeklyPercentUsed: payload.sevenDay?.percentUsed,
                nextResetAt: payload.fiveHour?.resetAt ?? payload.sevenDay?.resetAt,
                weeklyResetAt: payload.sevenDay?.resetAt,
                usageStatus: payload.usageStatus,
                sourceConfidence: 0.95,
                rawExtractedStrings: [],
                provider: .claude,
                totalTokensToday: nil,
                totalTokensThisWeek: nil
            )
        } catch {
            logger.warning("Failed to decode Claude usage response: \(error)")
            return nil
        }
    }

    private func fetchWithRetry(_ request: URLRequest) async throws -> (Data, URLResponse) {
        var lastError: Error?
        for attempt in 0..<3 {
            do {
                return try await performRequest(request)
            } catch {
                lastError = error
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: UInt64(500_000_000) * UInt64(attempt + 1))
                }
            }
        }
        throw lastError!
    }

    private static func claudeURL(path: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "claude.ai"
        components.path = path
        return components.url
    }

    private func fetchSubscriptionDetails(
        organizationUUID: String,
        cookieHeader: String
    ) async -> ClaudeSubscriptionDetailsResponse? {
        guard let url = Self.claudeURL(path: "/api/organizations/\(organizationUUID)/subscription_details") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue("https://claude.ai/settings/billing", forHTTPHeaderField: "Referer")
        request.setValue("https://claude.ai", forHTTPHeaderField: "Origin")

        do {
            let (data, response) = try await fetchWithRetry(request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }
            return try JSONDecoder().decode(ClaudeSubscriptionDetailsResponse.self, from: data)
        } catch {
            logger.debug("Failed to decode Claude subscription details: \(error)")
            return nil
        }
    }
}

func decodeUsagePayload(from rawBody: String) -> ClaudeUsageResponse? {
    guard let data = rawBody.data(using: .utf8) else { return nil }
    return try? JSONDecoder.claudeUsageDecoder.decode(ClaudeUsageResponse.self, from: data)
}

func decodeSubscriptionDetailsPayload(from rawBody: String) -> ClaudeSubscriptionDetailsResponse? {
    guard let data = rawBody.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(ClaudeSubscriptionDetailsResponse.self, from: data)
}

struct ClaudeUsageResponse: Decodable {
    struct UsageWindow: Decodable {
        let remainingPercent: Double?
        let usedPercent: Double?
        let utilization: Double?
        private let rawResetAt: Date?
        private let rawResetsAt: Date?

        enum CodingKeys: String, CodingKey {
            case remainingPercent = "remaining_percent"
            case usedPercent = "used_percent"
            case utilization
            case rawResetAt = "reset_at"
            case rawResetsAt = "resets_at"
        }

        var percentUsed: Double? {
            if let usedPercent {
                return clamped(usedPercent)
            }
            if let utilization {
                return clamped(utilization)
            }
            if let remainingPercent {
                return clamped(100 - remainingPercent)
            }
            return nil
        }

        var resetAt: Date? {
            rawResetAt ?? rawResetsAt
        }

        private func clamped(_ value: Double) -> Double {
            max(0, min(100, value))
        }
    }

    let fiveHour: UsageWindow?
    let sevenDay: UsageWindow?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }

    var usageStatus: UsageStatus {
        let utilization = [fiveHour?.percentUsed, sevenDay?.percentUsed].compactMap { $0 }

        guard !utilization.isEmpty else {
            return .unknown
        }
        if utilization.contains(where: { $0 >= 100 }) {
            return .coolingDown
        }
        return .available
    }
}

struct ClaudeSubscriptionDetailsResponse: Decodable {
    let nextChargeDate: Date?

    enum CodingKeys: String, CodingKey {
        case nextChargeDate = "next_charge_date"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let rawDate = try container.decodeIfPresent(String.self, forKey: .nextChargeDate) {
            nextChargeDate = parseClaudeCalendarDate(rawDate)
        } else {
            nextChargeDate = nil
        }
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

func parseClaudeCalendarDate(_ value: String) -> Date? {
    let components = value.split(separator: "-")
    guard components.count == 3,
          let year = Int(components[0]),
          let month = Int(components[1]),
          let day = Int(components[2]) else {
        return nil
    }

    var dateComponents = DateComponents()
    dateComponents.calendar = Calendar(identifier: .gregorian)
    dateComponents.timeZone = TimeZone(secondsFromGMT: 0)
    dateComponents.year = year
    dateComponents.month = month
    dateComponents.day = day
    dateComponents.hour = 12
    return dateComponents.date
}
