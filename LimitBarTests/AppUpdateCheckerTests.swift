import Testing
import Foundation
@testable import LimitBar

struct AppUpdateCheckerTests {
    @Test
    func normalizesVersionByRemovingLeadingV() {
        #expect(GitHubAppUpdateChecker.normalizedVersion("v0.1.2") == "0.1.2")
        #expect(GitHubAppUpdateChecker.normalizedVersion("V1.0.0") == "1.0.0")
    }

    @Test
    func comparesNumericVersionsCorrectly() {
        #expect(GitHubAppUpdateChecker.isVersion("0.1.1", newerThan: "0.1.0"))
        #expect(GitHubAppUpdateChecker.isVersion("0.2.0", newerThan: "0.1.9"))
        #expect(!GitHubAppUpdateChecker.isVersion("0.1.0", newerThan: "0.1.0"))
        #expect(!GitHubAppUpdateChecker.isVersion("0.1.0", newerThan: "0.1.1"))
    }

    @Test
    func returnsUpdateWhenLatestReleaseIsNewer() async {
        let checker = GitHubAppUpdateChecker(
            requestPerformer: { _ in
                let response = HTTPURLResponse(
                    url: URL(string: "https://github.com/muhamed1222/atlasbar.me/releases/tag/v0.1.1")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (Data(), response)
            },
            minimumCheckInterval: 0,
            downloadURL: URL(string: "https://limitbar.netlify.app/download/macos")!
        )

        let update = await checker.checkForUpdate(currentVersion: "0.1.0")

        #expect(update == AppUpdateInfo(
            version: "0.1.1",
            downloadURL: URL(string: "https://limitbar.netlify.app/download/macos")!
        ))
    }

    @Test
    func returnsNilWhenLatestReleaseMatchesCurrentVersion() async {
        let checker = GitHubAppUpdateChecker(
            requestPerformer: { _ in
                let response = HTTPURLResponse(
                    url: URL(string: "https://github.com/muhamed1222/atlasbar.me/releases/tag/v0.1.0")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (Data(), response)
            },
            minimumCheckInterval: 0
        )

        let update = await checker.checkForUpdate(currentVersion: "0.1.0")

        #expect(update == nil)
    }

    @Test
    func reusesCachedResultUntilThrottleExpires() async {
        actor Counter {
            var value = 0
            func increment() { value += 1 }
            func current() -> Int { value }
        }

        final class Clock: @unchecked Sendable {
            private let lock = NSLock()
            var currentTime = Date(timeIntervalSince1970: 0)

            func now() -> Date {
                lock.lock()
                defer { lock.unlock() }
                return currentTime
            }

            func set(_ value: Date) {
                lock.lock()
                currentTime = value
                lock.unlock()
            }
        }

        let counter = Counter()
        let clock = Clock()
        let checker = GitHubAppUpdateChecker(
            requestPerformer: { _ in
                await counter.increment()
                let response = HTTPURLResponse(
                    url: URL(string: "https://github.com/muhamed1222/atlasbar.me/releases/tag/v0.1.1")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (Data(), response)
            },
            now: { clock.now() },
            minimumCheckInterval: 900
        )

        _ = await checker.checkForUpdate(currentVersion: "0.1.0")
        _ = await checker.checkForUpdate(currentVersion: "0.1.0")
        #expect(await counter.current() == 1)

        clock.set(Date(timeIntervalSince1970: 901))
        _ = await checker.checkForUpdate(currentVersion: "0.1.0")
        #expect(await counter.current() == 2)
    }
}
