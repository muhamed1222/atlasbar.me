import Foundation

struct ClaudeUsageCoordinator: CurrentUsageProviding {
    private let webProvider: any CurrentUsageProviding
    private let localProvider: any CurrentUsageProviding

    init(
        webProvider: any CurrentUsageProviding,
        localProvider: any CurrentUsageProviding
    ) {
        self.webProvider = webProvider
        self.localProvider = localProvider
    }

    func fetchCurrentUsage() async -> CurrentUsagePayload? {
        let local = await localProvider.fetchCurrentUsage()
        if let web = await webProvider.fetchCurrentUsage() {
            return merge(web: web, local: local)
        }
        return local
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
            usageStatus: web.usageStatus,
            sourceConfidence: web.sourceConfidence,
            rawExtractedStrings: web.rawExtractedStrings,
            provider: web.provider,
            totalTokensToday: local.totalTokensToday,
            totalTokensThisWeek: local.totalTokensThisWeek
        )
    }
}
