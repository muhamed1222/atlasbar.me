import Testing
import Foundation
@testable import LimitBar

private struct FakeClaudeCredentialsReader: ClaudeCredentialsReading {
    let credentials: ClaudeCredentials?

    func readCredentials() -> ClaudeCredentials? {
        credentials
    }
}

private struct FakeClaudeCookieStore: ClaudeSessionCookieStoring {
    let cookie: String?

    func hasStoredCookie() -> Bool {
        cookie?.isEmpty == false
    }

    func cookieHeaderValue() -> String? {
        cookie
    }

    func saveCookie(_ rawValue: String) throws {}

    func clearCookie() throws {}
}

private struct SequencedCurrentUsageProvider: CurrentUsageProviding {
    let result: CurrentUsagePayload?

    func fetchCurrentUsage() async -> CurrentUsagePayload? {
        result
    }
}

struct ClaudeUsagePipelineTests {
    @Test
    func webProviderParsesClaudeUsageIntoPercents() async {
        let credentials = ClaudeCredentials(
            subscriptionType: "pro",
            accountIdentifier: "outcastsdev@gmail.com",
            organizationUUID: "org-123"
        )
        let provider = ClaudeWebUsageProvider(
            credentialsReader: FakeClaudeCredentialsReader(credentials: credentials),
            cookieStore: FakeClaudeCookieStore(cookie: "sessionKey=test-cookie"),
            performRequest: { request in
                #expect(request.value(forHTTPHeaderField: "Cookie") == "sessionKey=test-cookie")
                #expect(request.url?.absoluteString == "https://claude.ai/api/organizations/org-123/usage")
                let body = """
                {
                  "five_hour": {
                    "remaining_percent": 71,
                    "reset_at": "2026-04-03T10:00:00Z"
                  },
                  "seven_day": {
                    "remaining_percent": 43,
                    "reset_at": "2026-04-05T10:00:00Z"
                  }
                }
                """.data(using: .utf8)!
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (body, response)
            }
        )

        let payload = await provider.fetchCurrentUsage()

        #expect(payload?.accountIdentifier == "outcastsdev@gmail.com")
        #expect(payload?.planType == "pro")
        #expect(payload?.provider == "Claude")
        #expect(payload?.sessionPercentUsed == 29)
        #expect(payload?.weeklyPercentUsed == 57)
        #expect(payload?.usageStatus == .available)
        #expect(payload?.nextResetAt == ISO8601DateFormatter().date(from: "2026-04-03T10:00:00Z"))
    }

    @Test
    func usageCoordinatorFallsBackToLocalUsageWhenWebUnavailable() async {
        let local = CurrentUsagePayload(
            accountIdentifier: "outcastsdev@gmail.com",
            planType: "pro",
            subscriptionExpiresAt: nil,
            sessionPercentUsed: nil,
            weeklyPercentUsed: nil,
            nextResetAt: nil,
            usageStatus: .available,
            sourceConfidence: 0.6,
            rawExtractedStrings: [],
            provider: "Claude",
            totalTokensToday: 12_000,
            totalTokensThisWeek: 54_000
        )
        let pipeline = ClaudeUsagePipeline(
            localProvider: SequencedCurrentUsageProvider(result: local),
            webProvider: SequencedCurrentUsageProvider(result: nil)
        )

        let payload = await pipeline.fetchCurrentUsage()

        #expect(payload == local)
    }

    @Test
    func usageCoordinatorKeepsLocalTokenTotalsWhenWebQuotaSucceeds() async {
        let local = CurrentUsagePayload(
            accountIdentifier: "outcastsdev@gmail.com",
            planType: "pro",
            subscriptionExpiresAt: nil,
            sessionPercentUsed: nil,
            weeklyPercentUsed: nil,
            nextResetAt: nil,
            usageStatus: .available,
            sourceConfidence: 0.6,
            rawExtractedStrings: [],
            provider: "Claude",
            totalTokensToday: 12_000,
            totalTokensThisWeek: 54_000
        )
        let web = CurrentUsagePayload(
            accountIdentifier: "outcastsdev@gmail.com",
            planType: "pro",
            subscriptionExpiresAt: nil,
            sessionPercentUsed: 31,
            weeklyPercentUsed: 58,
            nextResetAt: Date(timeIntervalSince1970: 1_800_000_000),
            usageStatus: .available,
            sourceConfidence: 0.95,
            rawExtractedStrings: [],
            provider: "Claude",
            totalTokensToday: nil,
            totalTokensThisWeek: nil
        )
        let pipeline = ClaudeUsagePipeline(
            localProvider: SequencedCurrentUsageProvider(result: local),
            webProvider: SequencedCurrentUsageProvider(result: web)
        )

        let payload = await pipeline.fetchCurrentUsage()

        #expect(payload?.sessionPercentUsed == 31)
        #expect(payload?.weeklyPercentUsed == 58)
        #expect(payload?.totalTokensToday == 12_000)
        #expect(payload?.totalTokensThisWeek == 54_000)
    }
}
