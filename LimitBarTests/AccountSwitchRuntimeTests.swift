import Testing
import Foundation
@testable import LimitBar

private final class AccountSwitchRuntimeSessionSwitcherStub: @unchecked Sendable, CodexSessionSwitching {
    var resultEmail: String?
    var switchError: (any Error)?
    private(set) var switchedEmails: [String] = []

    func switchTo(email: String) async throws -> String {
        switchedEmails.append(email)
        if let switchError {
            throw switchError
        }
        return resultEmail ?? email
    }
}

@MainActor
struct AccountSwitchRuntimeTests {
    @Test
    func returnsNilForUnsupportedAccountsOrConcurrentSwitch() async {
        let sessionSwitcher = AccountSwitchRuntimeSessionSwitcherStub()
        let runtime = AccountSwitchRuntime(sessionSwitcher: sessionSwitcher)

        let concurrent = await runtime.switchAccount(
            Account(id: UUID(), provider: .codex, email: "user@example.com", label: nil),
            currentSwitchingAccountId: UUID()
        )
        let unsupported = await runtime.switchAccount(
            Account(id: UUID(), provider: .claude, email: "user@example.com", label: nil),
            currentSwitchingAccountId: nil
        )

        #expect(concurrent == nil)
        #expect(unsupported == nil)
        #expect(sessionSwitcher.switchedEmails.isEmpty)
    }

    @Test
    func returnsConfirmedEmailAndRefreshOnSuccess() async {
        let sessionSwitcher = AccountSwitchRuntimeSessionSwitcherStub()
        sessionSwitcher.resultEmail = "confirmed@example.com"
        let runtime = AccountSwitchRuntime(sessionSwitcher: sessionSwitcher)

        let result = await runtime.switchAccount(
            Account(id: UUID(), provider: .codex, email: "user@example.com", label: nil),
            currentSwitchingAccountId: nil
        )

        #expect(sessionSwitcher.switchedEmails == ["user@example.com"])
        #expect(result?.confirmedEmail == "confirmed@example.com")
        #expect(result?.errorMessage == nil)
        #expect(result?.shouldRefresh == true)
        #expect(result?.switchingAccountId == nil)
    }

    @Test
    func returnsErrorWithoutRefreshOnFailure() async {
        let sessionSwitcher = AccountSwitchRuntimeSessionSwitcherStub()
        sessionSwitcher.switchError = NSError(domain: "Switch", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Switch failed"
        ])
        let runtime = AccountSwitchRuntime(sessionSwitcher: sessionSwitcher)

        let result = await runtime.switchAccount(
            Account(id: UUID(), provider: .codex, email: "user@example.com", label: nil),
            currentSwitchingAccountId: nil
        )

        #expect(sessionSwitcher.switchedEmails == ["user@example.com"])
        #expect(result?.confirmedEmail == nil)
        #expect(result?.errorMessage == "Switch failed")
        #expect(result?.shouldRefresh == false)
        #expect(result?.switchingAccountId == nil)
    }
}
