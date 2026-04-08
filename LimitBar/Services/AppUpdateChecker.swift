import Foundation

private struct GitHubLatestRelease: Decodable {
    let tagName: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
    }
}

struct AppUpdateInfo: Equatable, Sendable {
    let version: String
    let downloadURL: URL
}

protocol AppUpdateChecking: Sendable {
    func checkForUpdate(currentVersion: String) async -> AppUpdateInfo?
}

actor GitHubAppUpdateChecker: AppUpdateChecking {
    typealias RequestPerformer = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    static let defaultDownloadURL = URL(string: "https://limitbar.netlify.app/download/macos")!
    private static let latestReleaseAPIURL = URL(string: "https://api.github.com/repos/muhamed1222/atlasbar.me/releases/latest")!

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

        var request = URLRequest(url: Self.latestReleaseAPIURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("LimitBar/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await requestPerformer(request)
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                return cachedResult
            }
            let release = try JSONDecoder().decode(GitHubLatestRelease.self, from: data)
            let latestVersion = Self.normalizedVersion(release.tagName)
            let currentVersion = Self.normalizedVersion(currentVersion)

            guard Self.isVersion(latestVersion, newerThan: currentVersion) else {
                cachedResult = nil
                return nil
            }

            let result = AppUpdateInfo(version: latestVersion, downloadURL: downloadURL)
            cachedResult = result
            return result
        } catch {
            return cachedResult
        }
    }

    static func normalizedVersion(_ rawVersion: String) -> String {
        var value = rawVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasPrefix("v") || value.hasPrefix("V") {
            value.removeFirst()
        }
        return value
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
}
