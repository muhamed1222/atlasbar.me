import Testing
import Foundation
@testable import LimitBar

private final class SessionSwitcherVaultSpy: AccountVaulting, @unchecked Sendable {
    private(set) var switchedEmails: [String] = []
    var activeEmailValue: String?

    func saveCurrentAuth(for email: String) throws {}

    func hasSavedAuth(for email: String) -> Bool {
        true
    }

    func switchTo(email: String) throws {
        switchedEmails.append(email)
        activeEmailValue = email
    }

    func activeEmail() -> String? {
        activeEmailValue
    }
}

@MainActor
private final class AppControllerSpy: CodexAppControlling {
    var terminateResult = true
    var runningResult = true
    private(set) var terminateCalls = 0
    private(set) var launchCalls = 0

    func terminateCodex() {
        terminateCalls += 1
    }

    func waitUntilTerminated(timeout: TimeInterval) async -> Bool {
        terminateResult
    }

    func launchCodex() throws {
        launchCalls += 1
    }

    func waitUntilRunning(timeout: TimeInterval) async -> Bool {
        runningResult
    }
}

private final class AuthReaderSequence: CodexAuthReading, @unchecked Sendable {
    private let values: [CodexAccountInfo?]
    private var index = 0

    init(_ values: [CodexAccountInfo?]) {
        self.values = values
    }

    func readAccountInfo() -> CodexAccountInfo? {
        defer {
            if index < values.count - 1 {
                index += 1
            }
        }
        return values[min(index, values.count - 1)]
    }
}

@MainActor
struct CodexSessionSwitcherTests {
    @Test
    func switchToReturnsConfirmedEmailAfterRestart() async throws {
        let vault = SessionSwitcherVaultSpy()
        let appController = AppControllerSpy()
        let authReader = AuthReaderSequence([
            CodexAccountInfo(email: "old@example.com", planType: nil, subscriptionExpiresAt: nil, accountId: nil),
            CodexAccountInfo(email: "target@example.com", planType: nil, subscriptionExpiresAt: nil, accountId: nil)
        ])
        let switcher = CodexSessionSwitcher(
            vault: vault,
            appController: appController,
            authReader: authReader
        )

        let confirmedEmail = try await switcher.switchTo(email: "target@example.com")

        #expect(confirmedEmail == "target@example.com")
        #expect(vault.switchedEmails == ["target@example.com"])
        #expect(appController.terminateCalls == 1)
        #expect(appController.launchCalls == 1)
    }

    @Test
    func switchToThrowsWhenAuthNeverConfirmsTargetIdentity() async {
        let vault = SessionSwitcherVaultSpy()
        let appController = AppControllerSpy()
        let authReader = AuthReaderSequence([
            CodexAccountInfo(email: "old@example.com", planType: nil, subscriptionExpiresAt: nil, accountId: nil)
        ])
        let switcher = CodexSessionSwitcher(
            vault: vault,
            appController: appController,
            authReader: authReader
        )

        await #expect(throws: CodexSessionSwitchError.self) {
            try await switcher.switchTo(email: "target@example.com")
        }
    }
}
