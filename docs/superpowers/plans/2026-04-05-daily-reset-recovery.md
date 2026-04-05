# Daily Reset Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make exhausted Codex accounts automatically become usable again when `nextResetAt` passes, persist that recovered state, and send a single “account available again” notification without waiting for a manual refresh.

**Architecture:** Add a persisted `stateOrigin` marker to `UsageSnapshot`, introduce a focused `DailyResetRecoveryCoordinator` that computes immediate recoveries and the next timer boundary, and wire `AppModel` to reconcile recovery on launch, after refresh, and when the timer fires. Server refresh remains authoritative and can overwrite locally predicted recovery.

**Tech Stack:** Swift 6, SwiftUI menu bar app, `@MainActor` `AppModel`, JSON persistence via `SnapshotStore`, local scheduling via `Task.sleep`, XCTest-style testing with the `Testing` package.

---

## File Structure

### Existing files to modify

- `/Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBar/Domain/UsageSnapshot.swift`
  Add persisted `SnapshotStateOrigin` and backward-compatible decoding.
- `/Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBar/App/AppModel.swift`
  Own the runtime timer task, call recovery reconciliation on launch/refresh/timer fire, and apply recovered state.
- `/Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBar/App/UsageStateCoordinator.swift`
  Preserve `stateOrigin` on refresh, and expose a small helper to persist recovered snapshots through the existing store path.
- `/Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBarTests/AppModelTests.swift`
  Add integration tests for launch reconciliation, timer-fired recovery, persistence, and notification dedupe.
- `/Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBarTests/SnapshotStoreTests.swift`
  Verify `stateOrigin` round-trips and defaults for legacy payloads.

### New files to create

- `/Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBar/App/DailyResetRecoveryCoordinator.swift`
  Pure reconciliation logic: decide which snapshots recover now and when the next timer should fire.
- `/Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBarTests/DailyResetRecoveryCoordinatorTests.swift`
  Unit tests for the pure reconciliation rules.

---

### Task 1: Add persisted snapshot origin and legacy-safe decoding

**Files:**
- Modify: `/Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBar/Domain/UsageSnapshot.swift`
- Test: `/Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBarTests/SnapshotStoreTests.swift`

- [ ] **Step 1: Write the failing persistence test for `stateOrigin` round-trip**

```swift
@Test
func roundTripSavesAndLoadsSnapshotStateOrigin() throws {
    let store = try makeTempStore()
    let snapshot = UsageSnapshot(
        id: UUID(),
        accountId: UUID(),
        sessionPercentUsed: 100,
        weeklyPercentUsed: 40,
        nextResetAt: Date(timeIntervalSince1970: 1_700_000_000),
        weeklyResetAt: Date(timeIntervalSince1970: 1_700_604_800),
        subscriptionExpiresAt: nil,
        planType: "plus",
        usageStatus: .exhausted,
        sourceConfidence: 1.0,
        lastSyncedAt: Date(timeIntervalSince1970: 1_700_000_100),
        rawExtractedStrings: [],
        totalTokensToday: nil,
        totalTokensThisWeek: nil,
        stateOrigin: .predictedReset
    )

    try store.save(PersistedState(accounts: [], snapshots: [snapshot]))
    let loaded = store.load()

    #expect(loaded.snapshots.first?.stateOrigin == .predictedReset)
}
```

- [ ] **Step 2: Write the failing legacy decode test for missing `stateOrigin`**

```swift
@Test
func loadDefaultsMissingSnapshotStateOriginToServer() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("LimitBarLegacyOrigin-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    let store = try SnapshotStore(directory: url)

    let payload = """
    {
      "accounts": [],
      "snapshots": [
        {
          "id": "\(UUID().uuidString)",
          "accountId": "\(UUID().uuidString)",
          "sessionPercentUsed": 100,
          "weeklyPercentUsed": 50,
          "nextResetAt": "2026-04-05T12:00:00Z",
          "usageStatus": "exhausted",
          "sourceConfidence": 1
        }
      ]
    }
    """

    try payload.data(using: .utf8)?.write(
        to: url.appendingPathComponent("state.json"),
        options: .atomic
    )

    let loaded = store.load()
    #expect(loaded.snapshots.first?.stateOrigin == .server)
}
```

- [ ] **Step 3: Run the focused persistence tests to verify they fail**

Run:

```bash
xcodebuild test -project /Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBar.xcodeproj -scheme LimitBar -destination 'platform=macOS' -only-testing:LimitBarTests/SnapshotStoreTests
```

Expected: compile or test failure because `stateOrigin` does not exist yet.

- [ ] **Step 4: Add the enum and field in `UsageSnapshot`**

```swift
enum SnapshotStateOrigin: String, Codable, Equatable {
    case server
    case predictedReset
}

struct UsageSnapshot: Identifiable, Equatable {
    let id: UUID
    var accountId: UUID
    var sessionPercentUsed: Double?
    var weeklyPercentUsed: Double?
    var nextResetAt: Date?
    var weeklyResetAt: Date? = nil
    var subscriptionExpiresAt: Date?
    var planType: String? = nil
    var usageStatus: UsageStatus
    var sourceConfidence: Double
    var lastSyncedAt: Date?
    var rawExtractedStrings: [String]
    var totalTokensToday: Int? = nil
    var totalTokensThisWeek: Int? = nil
    var stateOrigin: SnapshotStateOrigin = .server
}
```

- [ ] **Step 5: Add backward-compatible coding keys**

```swift
enum CodingKeys: String, CodingKey {
    case id, accountId
    case sessionPercentUsed, weeklyPercentUsed
    case nextResetAt, weeklyResetAt, subscriptionExpiresAt
    case planType
    case usageStatus, subscriptionStatus
    case sourceConfidence, lastSyncedAt
    case totalTokensToday, totalTokensThisWeek
    case stateOrigin
}

stateOrigin = try c.decodeIfPresent(SnapshotStateOrigin.self, forKey: .stateOrigin) ?? .server

try c.encode(stateOrigin, forKey: .stateOrigin)
```

- [ ] **Step 6: Run the focused persistence tests to verify they pass**

Run:

```bash
xcodebuild test -project /Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBar.xcodeproj -scheme LimitBar -destination 'platform=macOS' -only-testing:LimitBarTests/SnapshotStoreTests
```

Expected: `SnapshotStoreTests` pass.

- [ ] **Step 7: Commit**

```bash
git add /Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBar/Domain/UsageSnapshot.swift /Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBarTests/SnapshotStoreTests.swift
git commit -m "feat: persist snapshot recovery origin"
```

### Task 2: Build a pure daily reset recovery coordinator

**Files:**
- Create: `/Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBar/App/DailyResetRecoveryCoordinator.swift`
- Test: `/Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBarTests/DailyResetRecoveryCoordinatorTests.swift`

- [ ] **Step 1: Write the failing reconciliation tests**

```swift
@Test
func reconcileRecoversExhaustedSnapshotWhenResetPassed() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let coordinator = DailyResetRecoveryCoordinator()
    let accountId = UUID()
    let snapshot = UsageSnapshot(
        id: UUID(),
        accountId: accountId,
        sessionPercentUsed: 100,
        weeklyPercentUsed: 66,
        nextResetAt: now.addingTimeInterval(-60),
        weeklyResetAt: now.addingTimeInterval(4 * 24 * 60 * 60),
        subscriptionExpiresAt: now.addingTimeInterval(10 * 24 * 60 * 60),
        planType: "plus",
        usageStatus: .exhausted,
        sourceConfidence: 1,
        lastSyncedAt: now.addingTimeInterval(-300),
        rawExtractedStrings: [],
        totalTokensToday: nil,
        totalTokensThisWeek: nil,
        stateOrigin: .server
    )

    let outcome = coordinator.reconcile(
        accounts: [],
        snapshots: [snapshot],
        now: now
    )

    #expect(outcome.recoveredAccountIDs == [accountId])
    #expect(outcome.snapshots.first?.usageStatus == .available)
    #expect(outcome.snapshots.first?.sessionPercentUsed == 0)
    #expect(outcome.snapshots.first?.weeklyPercentUsed == 66)
    #expect(outcome.snapshots.first?.stateOrigin == .predictedReset)
}

@Test
func reconcileReturnsNextFutureResetForScheduler() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let coordinator = DailyResetRecoveryCoordinator()
    let soon = now.addingTimeInterval(300)
    let later = now.addingTimeInterval(900)

    let outcome = coordinator.reconcile(
        accounts: [],
        snapshots: [
            UsageSnapshot(
                id: UUID(),
                accountId: UUID(),
                sessionPercentUsed: 100,
                weeklyPercentUsed: 20,
                nextResetAt: later,
                weeklyResetAt: nil,
                subscriptionExpiresAt: nil,
                planType: nil,
                usageStatus: .exhausted,
                sourceConfidence: 1,
                lastSyncedAt: now,
                rawExtractedStrings: [],
                totalTokensToday: nil,
                totalTokensThisWeek: nil,
                stateOrigin: .server
            ),
            UsageSnapshot(
                id: UUID(),
                accountId: UUID(),
                sessionPercentUsed: 95,
                weeklyPercentUsed: 20,
                nextResetAt: soon,
                weeklyResetAt: nil,
                subscriptionExpiresAt: nil,
                planType: nil,
                usageStatus: .coolingDown,
                sourceConfidence: 1,
                lastSyncedAt: now,
                rawExtractedStrings: [],
                totalTokensToday: nil,
                totalTokensThisWeek: nil,
                stateOrigin: .server
            )
        ],
        now: now
    )

    #expect(outcome.nextRecoveryAt == soon)
    #expect(outcome.recoveredAccountIDs.isEmpty)
}
```

- [ ] **Step 2: Run the new coordinator tests to verify they fail**

Run:

```bash
xcodebuild test -project /Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBar.xcodeproj -scheme LimitBar -destination 'platform=macOS' -only-testing:LimitBarTests/DailyResetRecoveryCoordinatorTests
```

Expected: build failure because `DailyResetRecoveryCoordinator` does not exist yet.

- [ ] **Step 3: Create the coordinator types**

```swift
import Foundation

struct DailyResetRecoveryOutcome: Equatable {
    let snapshots: [UsageSnapshot]
    let recoveredAccountIDs: [UUID]
    let nextRecoveryAt: Date?
}

struct DailyResetRecoveryCoordinator: Sendable {
    func reconcile(
        accounts: [Account],
        snapshots: [UsageSnapshot],
        now: Date
    ) -> DailyResetRecoveryOutcome {
        var recoveredAccountIDs: [UUID] = []

        let updatedSnapshots = snapshots.map { snapshot in
            guard shouldRecover(snapshot: snapshot, now: now) else { return snapshot }

            recoveredAccountIDs.append(snapshot.accountId)
            var recovered = snapshot
            recovered.sessionPercentUsed = 0
            recovered.usageStatus = .available
            recovered.stateOrigin = .predictedReset
            recovered.lastSyncedAt = now
            return recovered
        }

        let nextRecoveryAt = updatedSnapshots
            .filter { shouldScheduleRecoveryTimer(for: $0, now: now) }
            .compactMap(\.nextResetAt)
            .min()

        return DailyResetRecoveryOutcome(
            snapshots: updatedSnapshots,
            recoveredAccountIDs: recoveredAccountIDs,
            nextRecoveryAt: nextRecoveryAt
        )
    }

    private func shouldRecover(snapshot: UsageSnapshot, now: Date) -> Bool {
        guard let nextResetAt = snapshot.nextResetAt else { return false }
        guard nextResetAt <= now else { return false }
        guard snapshot.sessionPercentUsed != nil else { return false }
        return snapshot.usageStatus == .exhausted
            || snapshot.usageStatus == .coolingDown
            || snapshot.usageStatus == .stale
    }

    private func shouldScheduleRecoveryTimer(for snapshot: UsageSnapshot, now: Date) -> Bool {
        guard let nextResetAt = snapshot.nextResetAt else { return false }
        guard nextResetAt > now else { return false }
        guard snapshot.sessionPercentUsed != nil else { return false }
        return snapshot.usageStatus == .exhausted
            || snapshot.usageStatus == .coolingDown
            || snapshot.usageStatus == .stale
    }
}
```

- [ ] **Step 4: Run the new coordinator tests to verify they pass**

Run:

```bash
xcodebuild test -project /Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBar.xcodeproj -scheme LimitBar -destination 'platform=macOS' -only-testing:LimitBarTests/DailyResetRecoveryCoordinatorTests
```

Expected: `DailyResetRecoveryCoordinatorTests` pass.

- [ ] **Step 5: Commit**

```bash
git add /Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBar/App/DailyResetRecoveryCoordinator.swift /Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBarTests/DailyResetRecoveryCoordinatorTests.swift
git commit -m "feat: add daily reset recovery coordinator"
```

### Task 3: Wire recovery into `AppModel` launch, refresh, and timer flow

**Files:**
- Modify: `/Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBar/App/AppModel.swift`
- Modify: `/Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBar/App/UsageStateCoordinator.swift`
- Test: `/Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBarTests/AppModelTests.swift`

- [ ] **Step 1: Write the failing integration test for launch-time recovery**

```swift
@Test
@MainActor
func initRecoversPastResetSnapshotImmediately() async {
    let account = Account(id: UUID(), provider: "Codex", email: "user@example.com", label: nil)
    let now = Date()
    let snapshot = UsageSnapshot(
        id: UUID(),
        accountId: account.id,
        sessionPercentUsed: 100,
        weeklyPercentUsed: 50,
        nextResetAt: now.addingTimeInterval(-120),
        weeklyResetAt: now.addingTimeInterval(3 * 24 * 60 * 60),
        subscriptionExpiresAt: now.addingTimeInterval(10 * 24 * 60 * 60),
        planType: "plus",
        usageStatus: .exhausted,
        sourceConfidence: 1,
        lastSyncedAt: now.addingTimeInterval(-600),
        rawExtractedStrings: [],
        totalTokensToday: nil,
        totalTokensThisWeek: nil,
        stateOrigin: .server
    )
    let notifications = RecordingNotificationManager()
    let store = InMemorySnapshotStore(state: PersistedState(accounts: [account], snapshots: [snapshot]))

    let model = AppModel(
        usageProvider: FakeCurrentUsageProvider(result: nil),
        runningChecker: FakeRunningChecker(isCodexRunning: true),
        notificationManager: notifications,
        store: store,
        shouldStartPolling: false
    )

    #expect(model.snapshot(for: account.id)?.usageStatus == .available)
    #expect(model.snapshot(for: account.id)?.sessionPercentUsed == 0)
    #expect(model.snapshot(for: account.id)?.stateOrigin == .predictedReset)
}
```

- [ ] **Step 2: Write the failing integration test for timer-fired recovery notification**

```swift
@Test
@MainActor
func recoveryTimerSchedulesAndNotifiesOnce() async {
    let account = Account(id: UUID(), provider: "Codex", email: "user@example.com", label: nil)
    let resetAt = Date().addingTimeInterval(0.2)
    let notifications = RecordingNotificationManager()
    let store = InMemorySnapshotStore(
        state: PersistedState(
            accounts: [account],
            snapshots: [
                UsageSnapshot(
                    id: UUID(),
                    accountId: account.id,
                    sessionPercentUsed: 100,
                    weeklyPercentUsed: 60,
                    nextResetAt: resetAt,
                    weeklyResetAt: nil,
                    subscriptionExpiresAt: nil,
                    planType: "plus",
                    usageStatus: .exhausted,
                    sourceConfidence: 1,
                    lastSyncedAt: Date(),
                    rawExtractedStrings: [],
                    totalTokensToday: nil,
                    totalTokensThisWeek: nil,
                    stateOrigin: .server
                )
            ]
        )
    )

    let model = AppModel(
        usageProvider: FakeCurrentUsageProvider(result: nil),
        runningChecker: FakeRunningChecker(isCodexRunning: true),
        notificationManager: notifications,
        store: store,
        shouldStartPolling: false
    )

    try? await Task.sleep(nanoseconds: 500_000_000)

    #expect(model.snapshot(for: account.id)?.usageStatus == .available)
    #expect(notifications.scheduled.count == 1)
}
```

- [ ] **Step 3: Run the focused `AppModelTests` to verify they fail**

Run:

```bash
xcodebuild test -project /Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBar.xcodeproj -scheme LimitBar -destination 'platform=macOS' -only-testing:LimitBarTests/AppModelTests
```

Expected: failing assertions because no launch reconciliation or timer-driven recovery exists.

- [ ] **Step 4: Add the coordinator dependency and a dedicated recovery task**

```swift
private let dailyResetRecoveryCoordinator: DailyResetRecoveryCoordinator
private var dailyResetRecoveryTask: Task<Void, Never>?

init(
    usageProvider: any CurrentUsageProviding = APIBasedUsageProvider(),
    runningChecker: any CodexRunningChecking = ProcessWatcher(),
    pollingCoordinator: PollingCoordinator = PollingCoordinator(),
    notificationManager: any NotificationScheduling = NotificationManager(),
    store: (any SnapshotStoring)? = nil,
    vault: (any AccountVaulting)? = nil,
    sessionSwitcher: (any CodexSessionSwitching)? = nil,
    claudeUsageProvider: (any CurrentUsageProviding)? = nil,
    claudeUsagePipeline: (any ClaudeUsagePipelining)? = nil,
    claudeCredentialsReader: (any ClaudeCredentialsReading)? = nil,
    claudeSessionCookieStore: (any ClaudeSessionCookieStoring)? = nil,
    claudeWebSessionController: (any ClaudeWebSessionControlling)? = nil,
    dailyResetRecoveryCoordinator: DailyResetRecoveryCoordinator = DailyResetRecoveryCoordinator(),
    shouldStartPolling: Bool = AppRuntimeDefaults.shouldStartPolling
) {
    self.dailyResetRecoveryCoordinator = dailyResetRecoveryCoordinator
    ...
}
```

- [ ] **Step 5: Add a single reconciliation method that applies state, persists, notifies, and reschedules**

```swift
private func reconcileDailyResetRecovery(now: Date = Date()) {
    let outcome = dailyResetRecoveryCoordinator.reconcile(
        accounts: accounts,
        snapshots: snapshots,
        now: now
    )

    let recoveredIDs = Set(outcome.recoveredAccountIDs)
    let didRecover = !recoveredIDs.isEmpty

    if didRecover {
        snapshots = outcome.snapshots
        persist()
        refreshCompactLabel()

        for accountId in recoveredIDs {
            guard let snapshot = snapshot(for: accountId),
                  let account = accounts.first(where: { $0.id == accountId }) else { continue }
            if settings.cooldownNotificationsEnabled {
                notificationManager.scheduleCooldownReadyNotification(
                    accountId: account.id,
                    accountName: account.displayName,
                    at: now.addingTimeInterval(1)
                )
            }
            notificationManager.cancelCooldownReadyNotification(
                accountId: account.id,
                accountName: account.displayName
            )
        }
    }

    scheduleDailyResetRecoveryTask(at: outcome.nextRecoveryAt)
}
```

- [ ] **Step 6: Add a dedicated timer scheduler**

```swift
private func scheduleDailyResetRecoveryTask(at date: Date?) {
    dailyResetRecoveryTask?.cancel()
    guard let date else { return }

    let delay = date.timeIntervalSinceNow
    guard delay > 0 else {
        Task { @MainActor [weak self] in
            self?.reconcileDailyResetRecovery()
        }
        return
    }

    dailyResetRecoveryTask = Task { @MainActor [weak self] in
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        guard !Task.isCancelled else { return }
        self?.reconcileDailyResetRecovery()
    }
}
```

- [ ] **Step 7: Call recovery reconciliation at the three integration points**

```swift
// end of init, after load + refreshCompactLabel
reconcileDailyResetRecovery()

// end of performRefresh, after snapshots are replaced and refreshCompactLabel runs
reconcileDailyResetRecovery()

deinit {
    timerTask?.cancel()
    dailyResetRecoveryTask?.cancel()
}
```

- [ ] **Step 8: Preserve `stateOrigin` correctly in refresh merges**

```swift
let snapshot = UsageSnapshot(
    id: UUID(),
    accountId: accountId,
    sessionPercentUsed: payload.sessionPercentUsed,
    weeklyPercentUsed: payload.weeklyPercentUsed,
    nextResetAt: payload.nextResetAt ?? previousSnapshot?.nextResetAt,
    weeklyResetAt: payload.weeklyResetAt ?? previousSnapshot?.weeklyResetAt,
    subscriptionExpiresAt: payload.subscriptionExpiresAt,
    planType: payload.planType ?? previousSnapshot?.planType,
    usageStatus: payload.usageStatus,
    sourceConfidence: payload.sourceConfidence,
    lastSyncedAt: Date(),
    rawExtractedStrings: payload.rawExtractedStrings,
    totalTokensToday: payload.totalTokensToday,
    totalTokensThisWeek: payload.totalTokensThisWeek,
    stateOrigin: .server
)
```

- [ ] **Step 9: Run the focused `AppModelTests` to verify they pass**

Run:

```bash
xcodebuild test -project /Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBar.xcodeproj -scheme LimitBar -destination 'platform=macOS' -only-testing:LimitBarTests/AppModelTests
```

Expected: launch recovery, timer recovery, and notification tests pass.

- [ ] **Step 10: Commit**

```bash
git add /Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBar/App/AppModel.swift /Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBar/App/UsageStateCoordinator.swift /Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBarTests/AppModelTests.swift
git commit -m "feat: recover daily session after reset time"
```

### Task 4: Add server-overwrites-prediction coverage and full regression run

**Files:**
- Modify: `/Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBarTests/AppModelTests.swift`

- [ ] **Step 1: Write the failing reconciliation test for server overwrite**

```swift
@Test
@MainActor
func refreshOverwritesPredictedResetWithServerTruth() async {
    let account = Account(id: UUID(), provider: "Codex", email: "user@example.com", label: nil)
    let existing = UsageSnapshot(
        id: UUID(),
        accountId: account.id,
        sessionPercentUsed: 0,
        weeklyPercentUsed: 55,
        nextResetAt: Date().addingTimeInterval(3600),
        weeklyResetAt: Date().addingTimeInterval(3 * 24 * 60 * 60),
        subscriptionExpiresAt: nil,
        planType: "plus",
        usageStatus: .available,
        sourceConfidence: 1,
        lastSyncedAt: Date(),
        rawExtractedStrings: [],
        totalTokensToday: nil,
        totalTokensThisWeek: nil,
        stateOrigin: .predictedReset
    )

    let providerPayload = CurrentUsagePayload(
        accountIdentifier: "user@example.com",
        planType: "plus",
        subscriptionExpiresAt: nil,
        sessionPercentUsed: 83,
        weeklyPercentUsed: 55,
        nextResetAt: Date().addingTimeInterval(4000),
        weeklyResetAt: Date().addingTimeInterval(3 * 24 * 60 * 60),
        usageStatus: .coolingDown,
        sourceConfidence: 1,
        rawExtractedStrings: [],
        provider: "Codex"
    )

    let model = AppModel(
        usageProvider: FakeCurrentUsageProvider(result: providerPayload),
        runningChecker: FakeRunningChecker(isCodexRunning: true),
        notificationManager: RecordingNotificationManager(),
        store: InMemorySnapshotStore(state: PersistedState(accounts: [account], snapshots: [existing])),
        vault: ActiveEmailVault(email: "user@example.com"),
        shouldStartPolling: false
    )

    await model.refreshNowAsync()

    #expect(model.snapshot(for: account.id)?.sessionPercentUsed == 83)
    #expect(model.snapshot(for: account.id)?.usageStatus == .coolingDown)
    #expect(model.snapshot(for: account.id)?.stateOrigin == .server)
}
```

- [ ] **Step 2: Run the focused `AppModelTests` to verify it fails first**

Run:

```bash
xcodebuild test -project /Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBar.xcodeproj -scheme LimitBar -destination 'platform=macOS' -only-testing:LimitBarTests/AppModelTests
```

Expected: failing assertion until refresh explicitly restores `stateOrigin = .server`.

- [ ] **Step 3: Make any minimal refresh merge fix needed and re-run**

Use the Task 3 refresh constructor exactly as written so provider snapshots always come back as `.server`, then rerun:

```bash
xcodebuild test -project /Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBar.xcodeproj -scheme LimitBar -destination 'platform=macOS' -only-testing:LimitBarTests/AppModelTests
```

Expected: `AppModelTests` pass.

- [ ] **Step 4: Run the full suite**

Run:

```bash
xcodebuild test -project /Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBar.xcodeproj -scheme LimitBar -destination 'platform=macOS'
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add /Users/kelemetovmuhamed/Documents/atlasbar.me/LimitBarTests/AppModelTests.swift
git commit -m "test: cover predicted reset reconciliation"
```

## Self-Review

### Spec coverage

- local daily-session recovery: covered by Tasks 2 and 3
- persistence of recovered state: covered by Tasks 1 and 3
- notification-on-recovery: covered by Task 3
- timer scheduling and re-scheduling: covered by Tasks 2 and 3
- server refresh overwrites predicted state: covered by Task 4
- weekly and subscription remain unchanged: covered by Task 2 assertions

### Placeholder scan

Checked for:

- `TODO`
- `TBD`
- vague “handle errors” instructions
- unnamed file paths

None remain in the plan.

### Type consistency

Consistent names used throughout:

- `SnapshotStateOrigin`
- `stateOrigin`
- `DailyResetRecoveryCoordinator`
- `DailyResetRecoveryOutcome`
- `reconcileDailyResetRecovery(now:)`
- `scheduleDailyResetRecoveryTask(at:)`

## Execution Handoff

Plan complete and saved to `/Users/kelemetovmuhamed/Documents/atlasbar.me/docs/superpowers/plans/2026-04-05-daily-reset-recovery.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
