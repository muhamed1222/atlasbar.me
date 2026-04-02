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
        guard let authInfo = authReader.readAccountInfo() else {
            return nil
        }

        let usageData = await usageFetcher.fetchUsage(authInfo: authInfo)

        return CurrentUsagePayload(
            accountIdentifier: authInfo.email,
            planType: authInfo.planType,
            subscriptionExpiresAt: authInfo.subscriptionExpiresAt,
            sessionPercentUsed: usageData?.sessionPercentUsed,
            weeklyPercentUsed: usageData?.weeklyPercentUsed,
            nextResetAt: usageData?.nextResetAt,
            usageStatus: usageData?.status ?? .unknown,
            sourceConfidence: usageData != nil ? 1.0 : 0.0,
            rawExtractedStrings: []
        )
    }
}
