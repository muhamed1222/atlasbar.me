import Foundation

protocol CodexUsageFetching: Sendable {
    func fetchUsage(authInfo: CodexAccountInfo) async -> CodexUsageData?
}

protocol CurrentUsageProviding: Sendable {
    func fetchCurrentUsage() async -> CurrentUsagePayload?
}

struct APIBasedUsageProvider: CurrentUsageProviding {
    private let authReader: any CodexAuthReading
    private let usageFetcher: any CodexUsageFetching

    init(
        authReader: any CodexAuthReading = CodexAuthReader(),
        usageFetcher: any CodexUsageFetching = CodexUsageAPI()
    ) {
        self.authReader = authReader
        self.usageFetcher = usageFetcher
    }

    func fetchCurrentUsage() async -> CurrentUsagePayload? {
        guard let initialAuthInfo = authReader.readAccountInfo() else {
            return nil
        }

        let usageData = await usageFetcher.fetchUsage(authInfo: initialAuthInfo)
        let refreshedAuthInfo = authReader.readAccountInfo() ?? initialAuthInfo

        return CurrentUsagePayload(
            accountIdentifier: refreshedAuthInfo.email ?? initialAuthInfo.email,
            planType: refreshedAuthInfo.planType,
            subscriptionExpiresAt: refreshedAuthInfo.subscriptionExpiresAt,
            sessionPercentUsed: usageData?.sessionPercentUsed,
            weeklyPercentUsed: usageData?.weeklyPercentUsed,
            nextResetAt: usageData?.nextResetAt,
            weeklyResetAt: usageData?.weeklyResetAt,
            usageStatus: usageData?.status ?? .unknown,
            sourceConfidence: usageData != nil ? 1.0 : 0.0,
            rawExtractedStrings: []
        )
    }
}
