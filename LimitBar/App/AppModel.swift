import Foundation
import AppKit
import OSLog

private let logger = Logger(subsystem: "me.atlasbar.LimitBar", category: "AppModel")

@MainActor
final class AppModel: ObservableObject {
    @Published var compactLabel: String = "--"
    @Published var codexRunning: Bool = false
    @Published var lastRefreshAt: Date?
    @Published var accounts: [Account] = []
    @Published var snapshots: [UsageSnapshot] = []

    private let processWatcher = ProcessWatcher()
    private let authReader = CodexAuthReader()
    private let usageAPI = CodexUsageAPI()
    private let pollingCoordinator = PollingCoordinator()
    private let notificationManager = NotificationManager()
    private let store: SnapshotStore?
    private var timerTask: Task<Void, Never>?

    init() {
        do {
            store = try SnapshotStore()
        } catch {
            logger.error("Failed to create SnapshotStore: \(error)")
            store = nil
        }
        let state = store?.load() ?? PersistedState(accounts: [], snapshots: [])
        accounts = deduplicated(state.accounts)
        snapshots = state.snapshots
        startPolling()
    }

    deinit {
        timerTask?.cancel()
    }

    func refreshNow() {
        Task { await performRefresh() }
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
        accounts = []
        snapshots = []
        do {
            try store?.reset()
        } catch {
            logger.error("Failed to reset store: \(error)")
        }
        compactLabel = "--"
    }

    func deleteAccount(_ account: Account) {
        accounts.removeAll { $0.id == account.id }
        snapshots.removeAll { $0.accountId == account.id }
        persist()

        if accounts.isEmpty {
            compactLabel = "--"
        } else if let latestSnapshot = snapshots.sorted(by: { ($0.lastSyncedAt ?? .distantPast) > ($1.lastSyncedAt ?? .distantPast) }).first {
            compactLabel = shortUsageLabel(snapshot: latestSnapshot)
        } else {
            compactLabel = "--"
        }
    }

    // MARK: - Polling

    private func startPolling() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.performRefresh()
                let running = await self?.codexRunning ?? false
                let interval = PollingCoordinator().interval(codexRunning: running)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    // MARK: - Core refresh

    private func performRefresh() async {
        lastRefreshAt = Date()

        let authInfo = authReader.readAccountInfo()
        let isRunning = processWatcher.runningCodexApp() != nil
        codexRunning = isRunning

        guard authInfo != nil else {
            compactLabel = "--"
            return
        }

        let accountId = upsertAccount(identifier: authInfo?.email, authInfo: authInfo)

        let usageData = await usageAPI.fetchUsage(authInfo: authInfo!)

        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: accountId,
            sessionPercentUsed: usageData?.sessionPercentUsed,
            weeklyPercentUsed: usageData?.weeklyPercentUsed,
            nextResetAt: usageData?.nextResetAt,
            subscriptionExpiresAt: authInfo?.subscriptionExpiresAt,
            usageStatus: usageData?.status ?? .unknown,
            subscriptionStatus: .unknown,
            sourceConfidence: usageData != nil ? 1.0 : 0.0,
            lastSyncedAt: Date(),
            rawExtractedStrings: []
        )

        snapshots = snapshots.filter { $0.accountId != accountId } + [snapshot]
        persist()
        compactLabel = shortUsageLabel(snapshot: snapshot)

        scheduleNotificationIfNeeded(snapshot: snapshot, accountId: accountId)
    }

    // MARK: - Helpers

    private func upsertAccount(identifier: String?, authInfo: CodexAccountInfo? = nil) -> UUID {
        if let identifier,
           let idx = accounts.firstIndex(where: { $0.email == identifier || $0.label == identifier }) {
            if let plan = authInfo?.planType, accounts[idx].note != plan {
                accounts[idx].note = plan
            }
            return accounts[idx].id
        }
        if identifier == nil,
           let existing = accounts.first(where: { $0.provider == Provider.codex.name && $0.email == nil && $0.label == nil }) {
            return existing.id
        }
        let isEmail = identifier?.contains("@") == true
        let account = Account(
            id: UUID(),
            provider: Provider.codex.name,
            email: isEmail ? identifier : nil,
            label: isEmail ? nil : identifier,
            note: authInfo?.planType,
            priority: nil
        )
        accounts.append(account)
        return account.id
    }

    private func deduplicated(_ accounts: [Account]) -> [Account] {
        var seen = Set<String>()
        return accounts.filter { account in
            let key = account.email ?? account.label ?? "__unknown__\(account.provider)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    private func persist() {
        do {
            try store?.save(PersistedState(accounts: accounts, snapshots: snapshots))
        } catch {
            logger.error("Failed to persist state: \(error)")
        }
    }

    private func scheduleNotificationIfNeeded(snapshot: UsageSnapshot, accountId: UUID) {
        guard let nextResetAt = snapshot.nextResetAt,
              let account = accounts.first(where: { $0.id == accountId }) else { return }
        notificationManager.scheduleCooldownReadyNotification(
            accountName: account.displayName,
            at: nextResetAt
        )
    }

    private func findAppByName(_ name: String) -> URL? {
        let paths = ["/Applications/\(name).app", "\(NSHomeDirectory())/Applications/\(name).app"]
        return paths.compactMap { URL(fileURLWithPath: $0) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }
}
