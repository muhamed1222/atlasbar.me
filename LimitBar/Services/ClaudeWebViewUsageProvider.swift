import Foundation
import OSLog

private let logger = Logger(subsystem: "me.atlasbar.LimitBar", category: "ClaudeWebViewUsageProvider")

struct ClaudeWebViewUsageProvider: CurrentUsageProviding {
    private let credentialsReader: any ClaudeCredentialsReading
    private let sessionController: any ClaudeWebSessionControlling
    private let fallbackWebProvider: (any CurrentUsageProviding)?

    init(
        credentialsReader: any ClaudeCredentialsReading = ClaudeKeychainReader(),
        sessionController: any ClaudeWebSessionControlling,
        fallbackWebProvider: (any CurrentUsageProviding)? = nil
    ) {
        self.credentialsReader = credentialsReader
        self.sessionController = sessionController
        self.fallbackWebProvider = fallbackWebProvider
    }

    func fetchCurrentUsage() async -> CurrentUsagePayload? {
        guard let credentials = credentialsReader.readCredentials() else {
            return await fallbackWebProvider?.fetchCurrentUsage()
        }

        if let result = await sessionController.fetchUsageResponse(organizationUUID: credentials.organizationUUID),
           result.organizationUUID == credentials.organizationUUID,
           (200...299).contains(result.status),
           let payload = decodeUsagePayload(from: result.body) {
            let subscriptionDetails = await sessionController.fetchSubscriptionDetailsResponse(
                organizationUUID: credentials.organizationUUID
            )
            let subscription = subscriptionDetails
                .flatMap { (200...299).contains($0.status) ? decodeSubscriptionDetailsPayload(from: $0.body) : nil }

            return CurrentUsagePayload(
                accountIdentifier: credentials.accountIdentifier,
                planType: credentials.subscriptionType,
                subscriptionExpiresAt: subscription?.nextChargeDate,
                sessionPercentUsed: payload.fiveHour?.percentUsed,
                weeklyPercentUsed: payload.sevenDay?.percentUsed,
                nextResetAt: payload.fiveHour?.resetAt ?? payload.sevenDay?.resetAt,
                weeklyResetAt: payload.sevenDay?.resetAt,
                usageStatus: payload.usageStatus,
                sourceConfidence: 0.98,
                rawExtractedStrings: [],
                provider: .claude,
                totalTokensToday: nil,
                totalTokensThisWeek: nil
            )
        }

        logger.debug("WebView fetch failed or returned no valid payload, falling back to cookie provider")
        return await fallbackWebProvider?.fetchCurrentUsage()
    }
}
