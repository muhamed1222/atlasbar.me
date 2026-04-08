import Foundation

struct AppUpdateInfo: Equatable, Sendable {
    let version: String
    let downloadURL: URL
    let releaseNotes: String?
}

protocol AppUpdateChecking: Sendable {
    func checkForUpdate(currentVersion: String) async -> AppUpdateInfo?
}

actor GitHubAppUpdateChecker: AppUpdateChecking {
    typealias RequestPerformer = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    static let defaultDownloadURL = URL(string: "https://limitbar.netlify.app/download/macos")!
    private static let latestReleasePageURL = URL(string: "https://github.com/muhamed1222/atlasbar.me/releases/latest")!

    private let requestPerformer: RequestPerformer
    private let now: @Sendable () -> Date
    private let minimumCheckInterval: TimeInterval
    private let downloadURL: URL

    private var lastCheckedAt: Date?
    private var cachedResult: AppUpdateInfo?

    init(
        requestPerformer: @escaping RequestPerformer = {
            try await URLSession.shared.data(for: $0)
        },
        now: @escaping @Sendable () -> Date = Date.init,
        minimumCheckInterval: TimeInterval = 15 * 60,
        downloadURL: URL = GitHubAppUpdateChecker.defaultDownloadURL
    ) {
        self.requestPerformer = requestPerformer
        self.now = now
        self.minimumCheckInterval = minimumCheckInterval
        self.downloadURL = downloadURL
    }

    func checkForUpdate(currentVersion: String) async -> AppUpdateInfo? {
        let currentTime = now()
        if let lastCheckedAt, currentTime.timeIntervalSince(lastCheckedAt) < minimumCheckInterval {
            return cachedResult
        }
        lastCheckedAt = currentTime

        var request = URLRequest(url: Self.latestReleasePageURL)
        request.setValue("LimitBar/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await requestPerformer(request)
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                return cachedResult
            }
            guard let latestTag = Self.latestTag(from: httpResponse.url) else {
                return cachedResult
            }
            let latestVersion = Self.normalizedVersion(latestTag)
            let normalizedCurrentVersion = Self.normalizedVersion(currentVersion)

            guard Self.isVersion(latestVersion, newerThan: normalizedCurrentVersion) else {
                cachedResult = nil
                return nil
            }

            let result = AppUpdateInfo(
                version: latestVersion,
                downloadURL: downloadURL,
                releaseNotes: Self.releaseNotes(from: data)
            )
            cachedResult = result
            return result
        } catch {
            return cachedResult
        }
    }

    private static func latestTag(from url: URL?) -> String? {
        guard let url else { return nil }
        let components = url.pathComponents
        guard
            let releasesIndex = components.firstIndex(of: "releases"),
            releasesIndex + 2 < components.count,
            components[releasesIndex + 1] == "tag"
        else {
            return nil
        }
        return components[releasesIndex + 2]
    }

    static func normalizedVersion(_ rawVersion: String) -> String {
        var value = rawVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasPrefix("v") || value.hasPrefix("V") {
            value.removeFirst()
        }
        return value
    }

    static func releaseNotes(from data: Data) -> String? {
        guard let html = String(data: data, encoding: .utf8) else { return nil }
        return releaseNotes(fromHTML: html)
    }

    static func releaseNotes(fromHTML html: String) -> String? {
        for pattern in [
            #"<meta[^>]+property="og:description"[^>]+content="([^"]+)""#,
            #"<meta[^>]+name="description"[^>]+content="([^"]+)""#
        ] {
            guard
                let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                let range = Range(match.range(at: 1), in: html)
            else {
                continue
            }

            let rawValue = String(html[range])
            if let notes = sanitizedReleaseNotes(rawValue) {
                return notes
            }
        }
        return nil
    }

    static func isVersion(_ lhs: String, newerThan rhs: String) -> Bool {
        let lhsComponents = numericComponents(for: lhs)
        let rhsComponents = numericComponents(for: rhs)
        let count = max(lhsComponents.count, rhsComponents.count)

        for index in 0..<count {
            let lhsValue = index < lhsComponents.count ? lhsComponents[index] : 0
            let rhsValue = index < rhsComponents.count ? rhsComponents[index] : 0
            if lhsValue != rhsValue {
                return lhsValue > rhsValue
            }
        }
        return false
    }

    private static func numericComponents(for version: String) -> [Int] {
        normalizedVersion(version)
            .split(separator: ".")
            .map { component in
                let numericPrefix = component.prefix { $0.isNumber }
                return Int(numericPrefix) ?? 0
            }
    }

    private static func sanitizedReleaseNotes(_ rawValue: String) -> String? {
        let decoded = decodeHTMLEntities(rawValue)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !decoded.isEmpty else { return nil }
        let maximumLength = 220
        guard decoded.count > maximumLength else { return decoded }
        let truncated = decoded.prefix(maximumLength - 1)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(truncated)…"
    }

    private static func decodeHTMLEntities(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#34;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }
}
