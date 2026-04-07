import Foundation

struct ClaudeUsageProvider: CurrentUsageProviding {
    private let credentialsReader: any ClaudeCredentialsReading
    private let jsonlReader: any ClaudeJSONLReading

    init(
        credentialsReader: any ClaudeCredentialsReading = ClaudeKeychainReader(),
        jsonlReader: any ClaudeJSONLReading = ClaudeJSONLReader()
    ) {
        self.credentialsReader = credentialsReader
        self.jsonlReader = jsonlReader
    }

    func fetchCurrentUsage() async -> CurrentUsagePayload? {
        let credentials = credentialsReader.readCredentials()
        let stats = jsonlReader.readStats()

        guard credentials != nil || stats.lastActiveAt != nil else {
            return nil
        }

        return CurrentUsagePayload(
            accountIdentifier: credentials?.accountIdentifier ?? "Claude Code",
            planType: credentials?.subscriptionType,
            subscriptionExpiresAt: nil,
            sessionPercentUsed: nil,
            weeklyPercentUsed: nil,
            nextResetAt: nil,
            usageStatus: .available,
            sourceConfidence: credentials != nil ? 1.0 : 0.5,
            rawExtractedStrings: [],
            provider: .claude,
            totalTokensToday: stats.totalTokensToday > 0 ? stats.totalTokensToday : nil,
            totalTokensThisWeek: stats.totalTokensThisWeek > 0 ? stats.totalTokensThisWeek : nil
        )
    }
}
