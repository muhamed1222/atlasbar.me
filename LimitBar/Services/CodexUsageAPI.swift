import Foundation
import OSLog

private let logger = Logger(subsystem: "me.atlasbar.LimitBar", category: "CodexUsageAPI")

struct CodexUsageAPI {
    private let accessTokenProvider: any CodexAccessTokenProviding
    private let usageClient: any CodexUsageRequesting

    init(
        accessTokenProvider: any CodexAccessTokenProviding = CodexAccessTokenProvider(),
        usageClient: any CodexUsageRequesting = CodexUsageClient()
    ) {
        self.accessTokenProvider = accessTokenProvider
        self.usageClient = usageClient
    }

    func fetchUsage(authInfo: CodexAccountInfo) async -> CodexUsageData? {
        guard let token = await accessTokenProvider.currentAccessToken() else {
            return nil
        }

        guard let accountId = authInfo.accountId else {
            logger.debug("No account_id in auth.json")
            return nil
        }

        return await usageClient.fetchUsage(accessToken: token, accountId: accountId)
    }
}

extension CodexUsageAPI: CodexUsageFetching {}
