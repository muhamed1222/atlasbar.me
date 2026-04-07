import Foundation

struct AccountSessionStateRuntime: Sendable {
    func canSwitch(
        to account: Account,
        switchingAccountId: UUID?,
        activeCodexEmail: String?,
        vault: any AccountVaulting
    ) -> Bool {
        guard switchingAccountId == nil else { return false }
        guard account.provider.isCodex else { return false }
        guard let email = account.email else { return false }
        guard !matches(email, activeCodexEmail) else { return false }
        return vault.hasSavedAuth(for: email)
    }

    func isActiveAccount(
        _ account: Account,
        activeCodexEmail: String?,
        activeClaudeAccountIdentifier: String?
    ) -> Bool {
        if account.provider.isCodex {
            guard let email = account.email else {
                return false
            }
            return matches(email, activeCodexEmail)
        }

        if account.provider.isClaude {
            guard let activeIdentifier = normalizedIdentifier(activeClaudeAccountIdentifier) else {
                return false
            }

            if matches(account.email, activeIdentifier) {
                return true
            }

            if matches(account.label, activeIdentifier) {
                return true
            }
        }

        return false
    }

    private func normalizedIdentifier(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func matches(_ lhs: String?, _ rhs: String?) -> Bool {
        guard let lhs = normalizedIdentifier(lhs),
              let rhs = normalizedIdentifier(rhs) else {
            return false
        }
        return lhs.caseInsensitiveCompare(rhs) == .orderedSame
    }
}
