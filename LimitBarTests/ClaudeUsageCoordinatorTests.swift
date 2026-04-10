import Testing
import Foundation
import WebKit
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

@MainActor
private final class LocalFakeClaudeWebSessionController: ClaudeWebSessionControlling {
    var webView: WKWebView { WKWebView(frame: .zero) }
    var resultByOrganization: [String: ClaudeWebFetchResult] = [:]
    var subscriptionResultByOrganization: [String: ClaudeWebFetchResult] = [:]

    func prepareLoginPage() {}
    func clearSession() async throws {
        resultByOrganization.removeAll()
        subscriptionResultByOrganization.removeAll()
    }
    func fetchUsageResponse(organizationUUID: String?) async -> ClaudeWebFetchResult? {
        guard let organizationUUID else { return nil }
        return resultByOrganization[organizationUUID]
    }
    func fetchSubscriptionDetailsResponse(organizationUUID: String?) async -> ClaudeWebFetchResult? {
        guard let organizationUUID else { return nil }
        return subscriptionResultByOrganization[organizationUUID]
    }
    func cachedUsageResponse(organizationUUID: String?) -> ClaudeWebFetchResult? {
        guard let organizationUUID else { return nil }
        return resultByOrganization[organizationUUID]
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
                let body: Data
                switch request.url?.absoluteString {
                case "https://claude.ai/api/organizations/org-123/usage":
                    body = """
                    {
                      "five_hour": {
                        "utilization": 29,
                        "resets_at": "2026-04-03T10:00:00Z"
                      },
                      "seven_day": {
                        "utilization": 57,
                        "resets_at": "2026-04-05T10:00:00Z"
                      }
                    }
                    """.data(using: .utf8)!
                case "https://claude.ai/api/organizations/org-123/subscription_details":
                    body = """
                    {
                      "next_charge_date": "2026-04-22",
                      "status": "active",
                      "billing_interval": "monthly",
                      "currency": "USD"
                    }
                    """.data(using: .utf8)!
                default:
                    Issue.record("Unexpected URL: \(request.url?.absoluteString ?? "nil")")
                    body = Data()
                }
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
        #expect(payload?.provider == .claude)
        #expect(payload?.sessionPercentUsed == 29)
        #expect(payload?.weeklyPercentUsed == 57)
        #expect(payload?.usageStatus == .available)
        #expect(payload?.nextResetAt == ISO8601DateFormatter().date(from: "2026-04-03T10:00:00Z"))
        #expect(payload?.subscriptionExpiresAt == parseClaudeCalendarDate("2026-04-22"))
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
            provider: .claude,
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
            provider: .claude,
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
            provider: .claude,
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

    @Test @MainActor
    func webViewProviderParsesClaudeSubscriptionRenewalDate() async {
        let credentials = ClaudeCredentials(
            subscriptionType: "pro",
            accountIdentifier: "outcastsdev@gmail.com",
            organizationUUID: "org-123"
        )
        let controller = LocalFakeClaudeWebSessionController()
        controller.resultByOrganization["org-123"] = ClaudeWebFetchResult(
            status: 200,
            body: """
            {
              "five_hour": {
                "utilization": 29,
                "resets_at": "2026-04-03T10:00:00Z"
              },
              "seven_day": {
                "utilization": 57,
                "resets_at": "2026-04-05T10:00:00Z"
              }
            }
            """,
            organizationUUID: "org-123"
        )
        controller.subscriptionResultByOrganization["org-123"] = ClaudeWebFetchResult(
            status: 200,
            body: """
            {
              "next_charge_date": "2026-04-22",
              "status": "active",
              "billing_interval": "monthly",
              "currency": "USD"
            }
            """,
            organizationUUID: "org-123"
        )

        let provider = ClaudeWebViewUsageProvider(
            credentialsReader: FakeClaudeCredentialsReader(credentials: credentials),
            sessionController: controller
        )

        let payload = await provider.fetchCurrentUsage()

        #expect(payload?.sessionPercentUsed == 29)
        #expect(payload?.weeklyPercentUsed == 57)
        #expect(payload?.subscriptionExpiresAt == parseClaudeCalendarDate("2026-04-22"))
    }
}
