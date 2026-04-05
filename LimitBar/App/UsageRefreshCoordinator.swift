import Foundation
import OSLog

private let refreshLogger = Logger(subsystem: "me.atlasbar.LimitBar", category: "UsageRefreshCoordinator")

struct UsageRefreshOutcome: Equatable {
    let codexRunning: Bool
    let activeCodexEmail: String?
    let accounts: [Account]
    let snapshots: [UsageSnapshot]
    let persistenceErrorDetails: String?
    let renewalReminderAccountId: UUID?
    let shouldReconcileCooldownNotifications: Bool
    let claudeWebSessionStatus: ClaudeWebSessionStatusProjection?
}

struct UsageRefreshCoordinator: Sendable {
    private let usageProvider: any CurrentUsageProviding
    private let claudeUsageProvider: (any CurrentUsageProviding)?
    private let claudeUsagePipeline: (any ClaudeUsagePipelining)?
    private let runningChecker: any CodexRunningChecking
    private let stateCoordinator: UsageStateCoordinator
    private let vault: any AccountVaulting
    private let claudeCredentialsReader: any ClaudeCredentialsReading
    private let claudeWebSessionController: (any ClaudeWebSessionControlling)?

    init(
        usageProvider: any CurrentUsageProviding,
        claudeUsageProvider: (any CurrentUsageProviding)?,
        claudeUsagePipeline: (any ClaudeUsagePipelining)?,
        runningChecker: any CodexRunningChecking,
        stateCoordinator: UsageStateCoordinator,
        vault: any AccountVaulting,
        claudeCredentialsReader: any ClaudeCredentialsReading,
        claudeWebSessionController: (any ClaudeWebSessionControlling)?
    ) {
        self.usageProvider = usageProvider
        self.claudeUsageProvider = claudeUsageProvider
        self.claudeUsagePipeline = claudeUsagePipeline
        self.runningChecker = runningChecker
        self.stateCoordinator = stateCoordinator
        self.vault = vault
        self.claudeCredentialsReader = claudeCredentialsReader
        self.claudeWebSessionController = claudeWebSessionController
    }

    func refresh(from state: PersistedState) async -> UsageRefreshOutcome {
        let codexRunning = runningChecker.isCodexRunning
        let vault = self.vault
        let usageProvider = self.usageProvider
        let claudeUsageProvider = self.claudeUsageProvider
        let claudeUsagePipeline = self.claudeUsagePipeline
        let stateCoordinator = self.stateCoordinator
        let claudeCredentialsReader = self.claudeCredentialsReader
        let claudeWebSessionController = self.claudeWebSessionController

        let activeCodexEmail = await Self.readActiveCodexEmail(vault: vault)
        if let activeCodexEmail {
            await Self.saveCurrentAuth(for: activeCodexEmail, vault: vault)
        }

        async let codexFetch = Self.fetchCurrentUsage(from: usageProvider)
        async let claudeFetch = Self.fetchCurrentUsage(from: claudeUsageProvider)
        let (codexUsage, claudeUsage) = await (codexFetch, claudeFetch)

        var workingState = state
        var persistenceErrorDetails: String?
        var renewalReminderAccountId: UUID?
        var shouldReconcileCooldownNotifications = false

        let codexStep = await Self.applyProviderRefresh(
            payload: codexUsage,
            provider: Provider.codex.name,
            staleIdentifier: activeCodexEmail,
            state: workingState,
            stateCoordinator: stateCoordinator
        )
        workingState = codexStep.state
        persistenceErrorDetails = codexStep.persistenceErrorDetails
        renewalReminderAccountId = codexStep.renewalReminderAccountId
        shouldReconcileCooldownNotifications = codexStep.shouldReconcileCooldownNotifications

        let claudeStep = await Self.applyProviderRefresh(
            payload: claudeUsage,
            provider: Provider.claude.name,
            staleIdentifier: nil,
            state: workingState,
            stateCoordinator: stateCoordinator
        )
        workingState = claudeStep.state
        if let claudeError = claudeStep.persistenceErrorDetails {
            persistenceErrorDetails = claudeError
        }
        shouldReconcileCooldownNotifications = shouldReconcileCooldownNotifications || claudeStep.shouldReconcileCooldownNotifications

        return UsageRefreshOutcome(
            codexRunning: codexRunning,
            activeCodexEmail: activeCodexEmail,
            accounts: workingState.accounts,
            snapshots: workingState.snapshots,
            persistenceErrorDetails: persistenceErrorDetails,
            renewalReminderAccountId: renewalReminderAccountId,
            shouldReconcileCooldownNotifications: shouldReconcileCooldownNotifications,
            claudeWebSessionStatus: await Self.cachedClaudeWebSessionStatus(
                claudeUsagePipeline: claudeUsagePipeline,
                claudeCredentialsReader: claudeCredentialsReader,
                claudeWebSessionController: claudeWebSessionController
            )
        )
    }

    private static func applyProviderRefresh(
        payload: CurrentUsagePayload?,
        provider: String,
        staleIdentifier: String?,
        state: PersistedState,
        stateCoordinator: UsageStateCoordinator
    ) async -> ProviderRefreshStepResult {
        return await Task.detached(priority: .userInitiated) {
            if let payload {
                do {
                    let projection = try stateCoordinator.applyRefresh(payload, to: state)
                    return ProviderRefreshStepResult(
                        state: projection.persistedState,
                        persistenceErrorDetails: nil,
                        renewalReminderAccountId: provider.caseInsensitiveCompare(Provider.codex.name) == .orderedSame
                            ? Self.mostRecentlySyncedAccountId(in: projection.snapshots)
                            : nil,
                        shouldReconcileCooldownNotifications: false
                    )
                } catch {
                    refreshLogger.error("Failed to apply \(provider, privacy: .public) refresh: \(error)")
                    return ProviderRefreshStepResult(
                        state: state,
                        persistenceErrorDetails: error.localizedDescription,
                        renewalReminderAccountId: nil,
                        shouldReconcileCooldownNotifications: false
                    )
                }
            }

            do {
                let projection: UsageStateProjection
                if provider.caseInsensitiveCompare(Provider.codex.name) == .orderedSame,
                   let staleIdentifier {
                    projection = try stateCoordinator.markAccountStale(
                        provider: provider,
                        identifier: staleIdentifier,
                        from: state
                    )
                } else {
                    projection = try stateCoordinator.markProviderStale(provider, from: state)
                }

                let hasProviderAccounts = projection.accounts.contains {
                    $0.provider.caseInsensitiveCompare(provider) == .orderedSame
                }
                return ProviderRefreshStepResult(
                    state: projection.persistedState,
                    persistenceErrorDetails: nil,
                    renewalReminderAccountId: nil,
                    shouldReconcileCooldownNotifications: hasProviderAccounts
                )
            } catch {
                refreshLogger.error("Failed to mark \(provider, privacy: .public) usage stale: \(error)")
                return ProviderRefreshStepResult(
                    state: state,
                    persistenceErrorDetails: error.localizedDescription,
                    renewalReminderAccountId: nil,
                    shouldReconcileCooldownNotifications: false
                )
            }
        }.value
    }

    private static func cachedClaudeWebSessionStatus(
        claudeUsagePipeline: (any ClaudeUsagePipelining)?,
        claudeCredentialsReader: any ClaudeCredentialsReading,
        claudeWebSessionController: (any ClaudeWebSessionControlling)?
    ) async -> ClaudeWebSessionStatusProjection? {
        if let claudeUsagePipeline {
            return await Task.detached(priority: .utility) {
                await claudeUsagePipeline.cachedWebSessionStatus()
            }.value
        }

        let organizationUUID = await Task.detached(priority: .utility) {
            claudeCredentialsReader.readCredentials()?.organizationUUID
        }.value

        guard let claudeWebSessionController,
              let organizationUUID else {
            return nil
        }

        return ClaudeWebSessionStatusProjection.evaluate(
            result: await claudeWebSessionController.cachedUsageResponse(organizationUUID: organizationUUID),
            expectedOrganizationUUID: organizationUUID
        )
    }

    private static func readActiveCodexEmail(vault: any AccountVaulting) async -> String? {
        return await Task.detached(priority: .utility) {
            vault.activeEmail()
        }.value
    }

    private static func saveCurrentAuth(for email: String, vault: any AccountVaulting) async {
        await Task.detached(priority: .utility) {
            try? vault.saveCurrentAuth(for: email)
        }.value
    }

    private static func fetchCurrentUsage(from provider: (any CurrentUsageProviding)?) async -> CurrentUsagePayload? {
        guard let provider else { return nil }
        return await Task.detached(priority: .userInitiated) {
            await provider.fetchCurrentUsage()
        }.value
    }

    private static func mostRecentlySyncedAccountId(in snapshots: [UsageSnapshot]) -> UUID? {
        snapshots.max { lhs, rhs in
            (lhs.lastSyncedAt ?? .distantPast) < (rhs.lastSyncedAt ?? .distantPast)
        }?.accountId
    }
}

private struct ProviderRefreshStepResult {
    let state: PersistedState
    let persistenceErrorDetails: String?
    let renewalReminderAccountId: UUID?
    let shouldReconcileCooldownNotifications: Bool
}
