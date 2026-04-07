import Testing
import Foundation
@testable import LimitBar

private struct AccountSessionRuntimeVaultStub: AccountVaulting {
    let savedEmails: Set<String>

    func saveCurrentAuth(for email: String) throws {
        _ = email
    }

    func hasSavedAuth(for email: String) -> Bool {
        savedEmails.contains(email.lowercased())
    }

    func switchTo(email: String) throws {
        _ = email
    }

    func activeEmail() -> String? {
        nil
    }
}

struct AccountSessionStateRuntimeTests {
    @Test
    func canSwitchRejectsActiveOrUnsupportedAccounts() {
        let runtime = AccountSessionStateRuntime()
        let vault = AccountSessionRuntimeVaultStub(savedEmails: ["target@example.com"])

        #expect(
            runtime.canSwitch(
                to: Account(id: UUID(), provider: .codex, email: "target@example.com", label: nil),
                switchingAccountId: nil,
                activeCodexEmail: "target@example.com",
                vault: vault
            ) == false
        )

        #expect(
            runtime.canSwitch(
                to: Account(id: UUID(), provider: .claude, email: "target@example.com", label: nil),
                switchingAccountId: nil,
                activeCodexEmail: "other@example.com",
                vault: vault
            ) == false
        )
    }

    @Test
    func canSwitchAllowsInactiveCodexAccountWithSavedAuth() {
        let runtime = AccountSessionStateRuntime()
        let vault = AccountSessionRuntimeVaultStub(savedEmails: ["target@example.com"])

        let result = runtime.canSwitch(
            to: Account(id: UUID(), provider: .codex, email: "TARGET@example.com", label: nil),
            switchingAccountId: nil,
            activeCodexEmail: "current@example.com",
            vault: vault
        )

        #expect(result == true)
    }

    @Test
    func activeMatchingSupportsCodexClaudeEmailAndClaudeLabel() {
        let runtime = AccountSessionStateRuntime()

        #expect(
            runtime.isActiveAccount(
                Account(id: UUID(), provider: .codex, email: "shared@example.com", label: nil),
                activeCodexEmail: "SHARED@example.com",
                activeClaudeAccountIdentifier: nil
            ) == true
        )

        #expect(
            runtime.isActiveAccount(
                Account(id: UUID(), provider: .claude, email: "shared@example.com", label: nil),
                activeCodexEmail: nil,
                activeClaudeAccountIdentifier: "shared@example.com"
            ) == true
        )

        #expect(
            runtime.isActiveAccount(
                Account(id: UUID(), provider: .claude, email: nil, label: "Claude Workspace"),
                activeCodexEmail: nil,
                activeClaudeAccountIdentifier: "  claude workspace "
            ) == true
        )
    }
}
