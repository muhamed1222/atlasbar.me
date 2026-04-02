import Foundation
import AppKit
import OSLog

private let logger = Logger(subsystem: "me.atlasbar.LimitBar", category: "AppModel")

private enum AppRuntimeDefaults {
    static var shouldStartPolling: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var compactLabel: String = "--"
    @Published var codexRunning: Bool = false
    @Published var lastRefreshAt: Date?
    @Published var accounts: [Account] = []
    @Published var snapshots: [UsageSnapshot] = []

    private let usageProvider: any CurrentUsageProviding
    private let runningChecker: any CodexRunningChecking
    private let pollingCoordinator: PollingCoordinator
    private let stateCoordinator: UsageStateCoordinator
    private var timerTask: Task<Void, Never>?

    init(
        usageProvider: any CurrentUsageProviding = APIBasedUsageProvider(),
        runningChecker: any CodexRunningChecking = ProcessWatcher(),
        pollingCoordinator: PollingCoordinator = PollingCoordinator(),
        notificationManager: any NotificationScheduling = NotificationManager(),
        store: (any SnapshotStoring)? = nil,
        shouldStartPolling: Bool = AppRuntimeDefaults.shouldStartPolling
    ) {
        self.usageProvider = usageProvider
        self.runningChecker = runningChecker
        self.pollingCoordinator = pollingCoordinator

        let resolvedStore: (any SnapshotStoring)?
        if let store {
            resolvedStore = store
        } else {
            do {
                resolvedStore = try SnapshotStore()
            } catch {
                logger.error("Failed to create SnapshotStore: \(error)")
                resolvedStore = nil
            }
        }
        self.stateCoordinator = UsageStateCoordinator(
            store: resolvedStore,
            notificationManager: notificationManager
        )

        let state = stateCoordinator.loadInitialState()
        accounts = state.accounts
        snapshots = state.snapshots
        if shouldStartPolling {
            self.startPolling()
        }
    }

    deinit {
        timerTask?.cancel()
    }

    func refreshNow() {
        Task { await refreshNowAsync() }
    }

    func refreshNowAsync() async {
        await performRefresh()
    }

    func openCodex() {
        let bundleIds = [
            "com.openai.codex",
            "com.openai.Codex",
            "openai.codex",
            "com.todesktop.230313mzl4w4u92"
        ]
        for id in bundleIds {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                NSWorkspace.shared.openApplication(at: url, configuration: .init())
                return
            }
        }
        if let url = findAppByName("Codex") {
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        } else {
            logger.warning("Could not find Codex app to open")
        }
    }

    func resetAllData() {
        do {
            let projection = try stateCoordinator.resetAll()
            accounts = projection.accounts
            snapshots = projection.snapshots
            compactLabel = projection.compactLabel
        } catch {
            logger.error("Failed to reset store: \(error)")
        }
    }

    func deleteAccount(_ account: Account) {
        do {
            let projection = try stateCoordinator.deleteAccount(
                account,
                from: currentPersistedState
            )
            accounts = projection.accounts
            snapshots = projection.snapshots
            compactLabel = projection.compactLabel
        } catch {
            logger.error("Failed to delete account from store: \(error)")
        }
    }

    // MARK: - Polling

    private func startPolling() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.performRefresh()
                let interval = self.pollingCoordinator.interval(codexRunning: self.codexRunning)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    // MARK: - Core refresh

    private func performRefresh() async {
        lastRefreshAt = Date()
        codexRunning = runningChecker.isCodexRunning

        guard let currentUsage = await usageProvider.fetchCurrentUsage() else {
            do {
                let projection = try stateCoordinator.markStale(from: currentPersistedState)
                accounts = projection.accounts
                snapshots = projection.snapshots
                compactLabel = projection.compactLabel
            } catch {
                logger.error("Failed to mark usage state stale: \(error)")
                compactLabel = staleUsageLabel(hasSnapshots: !snapshots.isEmpty)
            }
            return
        }
        do {
            let projection = try stateCoordinator.applyRefresh(
                currentUsage,
                to: currentPersistedState
            )
            accounts = projection.accounts
            snapshots = projection.snapshots
            compactLabel = projection.compactLabel
        } catch {
            logger.error("Failed to apply refreshed usage state: \(error)")
        }
    }

    // MARK: - Helpers

    private var currentPersistedState: PersistedState {
        PersistedState(accounts: accounts, snapshots: snapshots)
    }

    private func findAppByName(_ name: String) -> URL? {
        let paths = ["/Applications/\(name).app", "\(NSHomeDirectory())/Applications/\(name).app"]
        return paths.compactMap { URL(fileURLWithPath: $0) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }
}
