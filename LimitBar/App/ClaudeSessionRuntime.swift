import Foundation
import WebKit

struct ClaudeCookieMutationProjection: Equatable {
    var isConfigured: Bool
    var errorMessage: String?
    var shouldRefreshUsage: Bool
}

struct ClaudeWebSessionMutationProjection: Equatable {
    var didClearSession: Bool
    var errorMessage: String?
    var shouldRefreshUsage: Bool
}

@MainActor
struct ClaudeSessionRuntime: Sendable {
    private let pipeline: (any ClaudeUsagePipelining)?
    private let credentialsReader: any ClaudeCredentialsReading
    private let cookieStore: (any ClaudeSessionCookieStoring)?
    private let webSessionController: (any ClaudeWebSessionControlling)?

    init(
        pipeline: (any ClaudeUsagePipelining)?,
        credentialsReader: any ClaudeCredentialsReading,
        cookieStore: (any ClaudeSessionCookieStoring)?,
        webSessionController: (any ClaudeWebSessionControlling)?
    ) {
        self.pipeline = pipeline
        self.credentialsReader = credentialsReader
        self.cookieStore = cookieStore
        self.webSessionController = webSessionController
    }

    var isAvailable: Bool {
        webSessionController != nil
    }

    var isCookieConfigured: Bool {
        cookieStore?.hasStoredCookie() ?? false
    }

    var webView: WKWebView? {
        webSessionController?.webView
    }

    func prepareLoginPage() {
        webSessionController?.prepareLoginPage()
    }

    func saveCookie(_ rawValue: String) -> ClaudeCookieMutationProjection {
        guard let cookieStore else {
            return ClaudeCookieMutationProjection(
                isConfigured: false,
                errorMessage: nil,
                shouldRefreshUsage: false
            )
        }

        do {
            try cookieStore.saveCookie(rawValue)
            return ClaudeCookieMutationProjection(
                isConfigured: cookieStore.hasStoredCookie(),
                errorMessage: nil,
                shouldRefreshUsage: true
            )
        } catch {
            return ClaudeCookieMutationProjection(
                isConfigured: cookieStore.hasStoredCookie(),
                errorMessage: error.localizedDescription,
                shouldRefreshUsage: false
            )
        }
    }

    func clearCookie() -> ClaudeCookieMutationProjection {
        guard let cookieStore else {
            return ClaudeCookieMutationProjection(
                isConfigured: false,
                errorMessage: nil,
                shouldRefreshUsage: false
            )
        }

        do {
            try cookieStore.clearCookie()
            return ClaudeCookieMutationProjection(
                isConfigured: cookieStore.hasStoredCookie(),
                errorMessage: nil,
                shouldRefreshUsage: true
            )
        } catch {
            return ClaudeCookieMutationProjection(
                isConfigured: cookieStore.hasStoredCookie(),
                errorMessage: error.localizedDescription,
                shouldRefreshUsage: false
            )
        }
    }

    func clearWebSession() async -> ClaudeWebSessionMutationProjection {
        guard let webSessionController else {
            return ClaudeWebSessionMutationProjection(
                didClearSession: false,
                errorMessage: nil,
                shouldRefreshUsage: false
            )
        }

        do {
            try await webSessionController.clearSession()
            return ClaudeWebSessionMutationProjection(
                didClearSession: true,
                errorMessage: nil,
                shouldRefreshUsage: true
            )
        } catch {
            return ClaudeWebSessionMutationProjection(
                didClearSession: false,
                errorMessage: error.localizedDescription,
                shouldRefreshUsage: false
            )
        }
    }

    func refreshWebSessionStatus() async -> ClaudeWebSessionStatusProjection? {
        if let pipeline {
            return await pipeline.refreshWebSessionStatus()
        }

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
                result: webSessionController.cachedUsageResponse(
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
}
