import Foundation

protocol ClaudeUsagePipelining: CurrentUsageProviding, Sendable {
    func refreshWebSessionStatus() async -> ClaudeWebSessionStatusProjection?
    func cachedWebSessionStatus() async -> ClaudeWebSessionStatusProjection?
}

struct ClaudeWebSessionStatusProjection: Equatable, Sendable {
    let isConnected: Bool
    let errorMessage: String?

    static func evaluate(
        result: ClaudeWebFetchResult?,
        expectedOrganizationUUID: String
    ) -> ClaudeWebSessionStatusProjection {
        guard let result else {
            return ClaudeWebSessionStatusProjection(isConnected: false, errorMessage: nil)
        }

        guard result.organizationUUID == expectedOrganizationUUID else {
            return ClaudeWebSessionStatusProjection(
                isConnected: false,
                errorMessage: "Claude web session is connected to a different organization."
            )
        }

        guard (200...299).contains(result.status) else {
            return ClaudeWebSessionStatusProjection(
                isConnected: false,
                errorMessage: claudeWebSessionErrorMessage(for: result)
            )
        }

        guard decodeUsagePayload(from: result.body) != nil else {
            return ClaudeWebSessionStatusProjection(
                isConnected: false,
                errorMessage: "Claude usage endpoint returned an unreadable response."
            )
        }

        return ClaudeWebSessionStatusProjection(isConnected: true, errorMessage: nil)
    }

    private static func claudeWebSessionErrorMessage(for result: ClaudeWebFetchResult) -> String {
        let body = result.body.lowercased()
        if body.contains("account_session_invalid") {
            return "Claude web session is signed into a different account."
        }
        if body.contains("just a moment") || body.contains("cf_chl") || body.contains("cloudflare") {
            return "Claude blocked the embedded browser with a verification challenge."
        }
        if result.status == 403 {
            return "Claude denied usage access for the current web session."
        }
        if result.status == 401 {
            return "Claude web session expired. Sign in again."
        }
        return "Claude usage request failed (\(result.status))."
    }
}

struct ClaudeUsagePipeline: ClaudeUsagePipelining {
    private let credentialsReader: any ClaudeCredentialsReading
    private let localProvider: any CurrentUsageProviding
    private let webProvider: any CurrentUsageProviding
    private let webSessionController: (any ClaudeWebSessionControlling)?

    init(
        credentialsReader: any ClaudeCredentialsReading = ClaudeKeychainReader(),
        localProvider: any CurrentUsageProviding = ClaudeUsageProvider(),
        webProvider: any CurrentUsageProviding,
        webSessionController: (any ClaudeWebSessionControlling)? = nil
    ) {
        self.credentialsReader = credentialsReader
        self.localProvider = localProvider
        self.webProvider = webProvider
        self.webSessionController = webSessionController
    }

    func fetchCurrentUsage() async -> CurrentUsagePayload? {
        let local = await localProvider.fetchCurrentUsage()
        if let web = await webProvider.fetchCurrentUsage() {
            return merge(web: web, local: local)
        }
        return local
    }

    func refreshWebSessionStatus() async -> ClaudeWebSessionStatusProjection? {
        guard let webSessionController else { return nil }
        guard let requestedOrganizationUUID = credentialsReader.readCredentials()?.organizationUUID else {
            return ClaudeWebSessionStatusProjection(isConnected: false, errorMessage: nil)
        }

        let result = await webSessionController.fetchUsageResponse(
            organizationUUID: requestedOrganizationUUID
        )
        let currentOrganizationUUID = credentialsReader.readCredentials()?.organizationUUID

        guard currentOrganizationUUID == requestedOrganizationUUID else {
            guard let currentOrganizationUUID else {
                return ClaudeWebSessionStatusProjection(isConnected: false, errorMessage: nil)
            }

            return ClaudeWebSessionStatusProjection.evaluate(
                result: await webSessionController.cachedUsageResponse(
                    organizationUUID: currentOrganizationUUID
                ),
                expectedOrganizationUUID: currentOrganizationUUID
            )
        }

        return ClaudeWebSessionStatusProjection.evaluate(
            result: result,
            expectedOrganizationUUID: requestedOrganizationUUID
        )
    }

    func cachedWebSessionStatus() async -> ClaudeWebSessionStatusProjection? {
        guard let webSessionController,
              let organizationUUID = credentialsReader.readCredentials()?.organizationUUID else {
            return nil
        }

        return ClaudeWebSessionStatusProjection.evaluate(
            result: await webSessionController.cachedUsageResponse(organizationUUID: organizationUUID),
            expectedOrganizationUUID: organizationUUID
        )
    }

    private func merge(web: CurrentUsagePayload, local: CurrentUsagePayload?) -> CurrentUsagePayload {
        guard let local else { return web }

        return CurrentUsagePayload(
            accountIdentifier: web.accountIdentifier ?? local.accountIdentifier,
            planType: web.planType ?? local.planType,
            subscriptionExpiresAt: web.subscriptionExpiresAt ?? local.subscriptionExpiresAt,
            sessionPercentUsed: web.sessionPercentUsed,
            weeklyPercentUsed: web.weeklyPercentUsed,
            nextResetAt: web.nextResetAt ?? local.nextResetAt,
            weeklyResetAt: web.weeklyResetAt ?? local.weeklyResetAt,
            usageStatus: web.usageStatus,
            sourceConfidence: web.sourceConfidence,
            rawExtractedStrings: web.rawExtractedStrings,
            provider: web.provider,
            totalTokensToday: local.totalTokensToday,
            totalTokensThisWeek: local.totalTokensThisWeek
        )
    }
}
