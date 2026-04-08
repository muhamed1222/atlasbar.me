import Foundation
import WebKit

@MainActor
protocol ClaudeWebSessionControlling: AnyObject, Sendable {
    var webView: WKWebView { get }
    func prepareLoginPage()
    func clearSession() async throws
    func fetchUsageResponse(organizationUUID: String?) async -> ClaudeWebFetchResult?
    func fetchSubscriptionDetailsResponse(organizationUUID: String?) async -> ClaudeWebFetchResult?
    func cachedUsageResponse(organizationUUID: String?) -> ClaudeWebFetchResult?
}

@MainActor
final class ClaudeWebSessionController: NSObject, ObservableObject, @unchecked Sendable, ClaudeWebSessionControlling {
    private let websiteDataStore: WKWebsiteDataStore
    private var usageResultsByOrganization: [String: ClaudeWebFetchResult] = [:]
    private lazy var internalWebView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = websiteDataStore
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }()

    private var navigationContinuation: CheckedContinuation<Void, Error>?
    private var pendingNavigationTask: Task<Void, Error>?

    override init() {
        self.websiteDataStore = .default()
        super.init()
    }

    var webView: WKWebView {
        internalWebView
    }

    func prepareLoginPage() {
        guard pendingNavigationTask == nil else { return }
        if internalWebView.url?.host == "claude.ai" { return }
        internalWebView.load(URLRequest(url: Self.usageURL))
    }

    func hasUsableSession() async -> Bool {
        do {
            try await ensureUsagePageLoaded()
            let result = try await execute(script: Self.accountProfileScript)
            return result.status == 200
        } catch {
            return false
        }
    }

    func clearSession() async throws {
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        let records = await websiteDataStore.dataRecords(ofTypes: dataTypes)
        let claudeRecords = records.filter { $0.displayName.localizedCaseInsensitiveContains("claude.ai") }
        await websiteDataStore.removeData(ofTypes: dataTypes, for: claudeRecords)
        usageResultsByOrganization.removeAll()
        internalWebView.loadHTMLString("", baseURL: nil)
    }

    func fetchUsageResponse(organizationUUID: String?) async -> ClaudeWebFetchResult? {
        do {
            try await ensureUsagePageLoaded()
            let result = try await execute(
                script: Self.usageScript,
                arguments: ["organizationUUID": organizationUUID as Any]
            )
            if let organizationUUID = result.organizationUUID {
                usageResultsByOrganization[organizationUUID] = result
            }
            return result
        } catch {
            if let organizationUUID {
                usageResultsByOrganization.removeValue(forKey: organizationUUID)
            }
            return nil
        }
    }

    func cachedUsageResponse(organizationUUID: String?) -> ClaudeWebFetchResult? {
        guard let organizationUUID else { return nil }
        return usageResultsByOrganization[organizationUUID]
    }

    func fetchSubscriptionDetailsResponse(organizationUUID: String?) async -> ClaudeWebFetchResult? {
        do {
            try await ensureUsagePageLoaded()
            return try await execute(
                script: Self.subscriptionDetailsScript,
                arguments: ["organizationUUID": organizationUUID as Any]
            )
        } catch {
            return nil
        }
    }

    private func ensureUsagePageLoaded() async throws {
        if internalWebView.url?.host == "claude.ai", internalWebView.isLoading == false {
            return
        }

        if let pending = pendingNavigationTask {
            try await pending.value
            return
        }

        let task = Task<Void, Error> {
            try await withCheckedThrowingContinuation { continuation in
                self.navigationContinuation = continuation
                self.internalWebView.load(URLRequest(url: Self.usageURL))
            }
        }
        pendingNavigationTask = task
        defer { pendingNavigationTask = nil }
        try await task.value
    }

    private func execute(
        script: String,
        arguments: [String: Any] = [:]
    ) async throws -> ClaudeWebFetchResult {
        let raw = try await internalWebView.callAsyncJavaScript(
            script,
            arguments: arguments,
            in: nil,
            contentWorld: .page
        )

        if let result = raw as? ClaudeWebFetchResult {
            return result
        }

        if let dictionary = raw as? [String: Any] {
            let data = try JSONSerialization.data(withJSONObject: dictionary)
            return try JSONDecoder().decode(ClaudeWebFetchResult.self, from: data)
        }

        throw ClaudeWebSessionError.invalidJavaScriptResult
    }

    private static let usageURL = URL(string: "https://claude.ai/settings/usage")!

    private static let accountProfileScript = """
        const response = await fetch('/api/account_profile', {
          credentials: 'include',
          headers: { Accept: 'application/json, text/plain, */*' }
        });
        return {
          status: response.status,
          body: await response.text(),
          url: window.location.href,
          organizationUUID: null
        };
        """

    private static let usageScript = """
        const argOrg = arguments.organizationUUID ?? null;
        const cookieMatch = document.cookie.match(/(?:^|;\\s*)lastActiveOrg=([^;]+)/);
        const resolvedOrg = argOrg ?? (cookieMatch ? decodeURIComponent(cookieMatch[1]) : null);

        if (!resolvedOrg) {
          return {
            status: 0,
            body: '',
            url: window.location.href,
            organizationUUID: null
          };
        }

        const response = await fetch(`/api/organizations/${resolvedOrg}/usage`, {
          credentials: 'include',
          headers: { Accept: 'application/json, text/plain, */*' }
        });

        return {
          status: response.status,
          body: await response.text(),
          url: window.location.href,
          organizationUUID: resolvedOrg
        };
        """

    private static let subscriptionDetailsScript = """
        const argOrg = arguments.organizationUUID ?? null;
        const cookieMatch = document.cookie.match(/(?:^|;\\s*)lastActiveOrg=([^;]+)/);
        const resolvedOrg = argOrg ?? (cookieMatch ? decodeURIComponent(cookieMatch[1]) : null);

        if (!resolvedOrg) {
          return {
            status: 0,
            body: '',
            url: window.location.href,
            organizationUUID: null
          };
        }

        const response = await fetch(`/api/organizations/${resolvedOrg}/subscription_details`, {
          credentials: 'include',
          headers: { Accept: 'application/json, text/plain, */*' }
        });

        return {
          status: response.status,
          body: await response.text(),
          url: window.location.href,
          organizationUUID: resolvedOrg
        };
        """
}

extension ClaudeWebSessionController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        navigationContinuation?.resume(returning: ())
        navigationContinuation = nil
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        navigationContinuation?.resume(throwing: error)
        navigationContinuation = nil
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        navigationContinuation?.resume(throwing: error)
        navigationContinuation = nil
    }
}

struct ClaudeWebFetchResult: Decodable, Sendable {
    let status: Int
    let body: String
    let url: String
    let organizationUUID: String?
}

enum ClaudeWebSessionError: Error {
    case invalidJavaScriptResult
}
