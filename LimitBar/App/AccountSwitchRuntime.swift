import Foundation

struct AccountSwitchProjection: Equatable {
    let switchingAccountId: UUID?
    let confirmedEmail: String?
    let errorMessage: String?
    let shouldRefresh: Bool
}

@MainActor
struct AccountSwitchRuntime {
    private let sessionSwitcher: any CodexSessionSwitching

    init(sessionSwitcher: any CodexSessionSwitching) {
        self.sessionSwitcher = sessionSwitcher
    }

    func switchAccount(
        _ account: Account,
        currentSwitchingAccountId: UUID?
    ) async -> AccountSwitchProjection? {
        guard currentSwitchingAccountId == nil else { return nil }
        guard account.provider.isCodex else { return nil }
        guard let email = account.email else { return nil }

        do {
            let confirmedEmail = try await sessionSwitcher.switchTo(email: email)
            return AccountSwitchProjection(
                switchingAccountId: nil,
                confirmedEmail: confirmedEmail,
                errorMessage: nil,
                shouldRefresh: true
            )
        } catch {
            return AccountSwitchProjection(
                switchingAccountId: nil,
                confirmedEmail: nil,
                errorMessage: error.localizedDescription,
                shouldRefresh: false
            )
        }
    }
}
