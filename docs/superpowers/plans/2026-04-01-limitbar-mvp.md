# LimitBar MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS menu bar MVP that detects Codex, reads visible usage/reset text via Accessibility, stores account snapshots locally, shows account state in the menu bar, and schedules local cooldown notifications.

**Architecture:** Use a small SwiftUI menu bar app with a single polling coordinator. Split runtime responsibilities into process detection, accessibility extraction, parsing, persistence, and notification scheduling. Treat Codex as a read-only external provider and store only normalized snapshots plus raw extracted strings for debugging and parser hardening.

**Tech Stack:** Swift, SwiftUI, MenuBarExtra, ApplicationServices Accessibility API, UserNotifications, Xcode unit tests

---

## Planned File Structure

- `LimitBar/LimitBarApp.swift`
  App entry, `MenuBarExtra`, dependency wiring.
- `LimitBar/App/AppModel.swift`
  Main observable app state, refresh orchestration, timer handling.
- `LimitBar/App/PollingCoordinator.swift`
  Adaptive polling intervals based on Codex process/window availability.
- `LimitBar/Domain/Provider.swift`
  Provider model.
- `LimitBar/Domain/Account.swift`
  Account model.
- `LimitBar/Domain/UsageSnapshot.swift`
  Snapshot and status models.
- `LimitBar/Services/ProcessWatcher.swift`
  Codex process/window detection.
- `LimitBar/Services/AccessibilityReader.swift`
  Accessibility permission checks and recursive text extraction.
- `LimitBar/Services/UsageParser.swift`
  Regex-based extraction and confidence scoring.
- `LimitBar/Services/SnapshotStore.swift`
  Local JSON persistence for accounts and snapshots.
- `LimitBar/Services/NotificationManager.swift`
  Local notification permission and cooldown scheduling.
- `LimitBar/UI/MenuBarRootView.swift`
  Dropdown container and top-level actions.
- `LimitBar/UI/CompactStatusView.swift`
  Compact menu bar label content.
- `LimitBar/UI/AccountRowView.swift`
  Per-account row in dropdown.
- `LimitBar/UI/SettingsView.swift`
  Settings window for polling/notifications/permissions.
- `LimitBar/Support/DateFormatting.swift`
  Shared date/countdown formatting helpers.
- `LimitBar/Support/ParserPatterns.swift`
  Central parser regex/pattern definitions.
- `LimitBarTests/UsageParserTests.swift`
  Parser-focused unit tests with raw text fixtures.
- `LimitBarTests/AppModelTests.swift`
  Refresh/status transition tests.
- `LimitBarTests/SnapshotStoreTests.swift`
  Persistence round-trip tests.
- `LimitBarTests/Fixtures/codex-*.txt`
  Captured accessibility text samples for realistic parser tests.

## Scope Guardrails

- V1 is `Codex only`.
- OCR fallback is explicitly out of scope.
- Subscription parsing is out of scope unless a real, stable text sample is captured during spike validation.
- “Best account suggestion” is out of scope.
- Multi-provider abstractions stay lightweight: keep one `Provider` model and one `UsageParser` implementation for Codex.

### Task 1: Bootstrap macOS Menu Bar Shell

**Files:**
- Create: `LimitBar.xcodeproj`
- Create: `LimitBar/LimitBarApp.swift`
- Create: `LimitBar/App/AppModel.swift`
- Create: `LimitBar/UI/MenuBarRootView.swift`
- Create: `LimitBar/UI/CompactStatusView.swift`

- [ ] **Step 1: Create the Xcode project**

Create a new macOS App project named `LimitBar` with:

```text
Interface: SwiftUI
Language: Swift
Use Core Data: No
Include Tests: Yes
Minimum target: macOS 14 or newer
```

- [ ] **Step 2: Replace the default app entry with a menu bar app**

Use this starter in `LimitBar/LimitBarApp.swift`:

```swift
import SwiftUI

@main
struct LimitBarApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarRootView()
                .environmentObject(appModel)
        } label: {
            CompactStatusView()
                .environmentObject(appModel)
        }

        Settings {
            Text("Settings")
                .frame(width: 320, height: 220)
        }
    }
}
```

- [ ] **Step 3: Add the first observable app state**

Use this starter in `LimitBar/App/AppModel.swift`:

```swift
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var compactLabel: String = "--"
    @Published var codexRunning: Bool = false
    @Published var lastRefreshAt: Date?

    func refreshNow() {
        lastRefreshAt = Date()
    }
}
```

- [ ] **Step 4: Add the first dropdown UI**

Use this starter in `LimitBar/UI/MenuBarRootView.swift`:

```swift
import SwiftUI

struct MenuBarRootView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appModel.codexRunning ? "Codex detected" : "Codex not running")
            if let lastRefreshAt = appModel.lastRefreshAt {
                Text("Last refresh: \(lastRefreshAt.formatted())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button("Refresh now") {
                appModel.refreshNow()
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 320)
    }
}
```

- [ ] **Step 5: Add the compact label**

Use this starter in `LimitBar/UI/CompactStatusView.swift`:

```swift
import SwiftUI

struct CompactStatusView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Text(appModel.compactLabel)
            .monospacedDigit()
    }
}
```

- [ ] **Step 6: Run the app**

Run from Xcode:

```text
Product > Run
```

Expected:
- app launches without a dock-first workflow issue;
- a menu bar item appears;
- clicking it opens the basic dropdown.

- [ ] **Step 7: Commit**

```bash
git add LimitBar.xcodeproj LimitBar
git commit -m "feat: bootstrap limitbar menu bar shell"
```

### Task 2: Add Domain Models and Local Persistence

**Files:**
- Create: `LimitBar/Domain/Provider.swift`
- Create: `LimitBar/Domain/Account.swift`
- Create: `LimitBar/Domain/UsageSnapshot.swift`
- Create: `LimitBar/Services/SnapshotStore.swift`
- Test: `LimitBarTests/SnapshotStoreTests.swift`

- [ ] **Step 1: Add the domain models**

Use this implementation in `LimitBar/Domain/UsageSnapshot.swift`:

```swift
import Foundation

enum UsageStatus: String, Codable {
    case available
    case coolingDown
    case exhausted
    case unknown
    case stale
}

enum SubscriptionStatus: String, Codable {
    case active
    case expiringSoon
    case expired
    case unknown
}

struct UsageSnapshot: Identifiable, Codable, Equatable {
    let id: UUID
    var accountId: UUID
    var dailyPercentUsed: Double?
    var weeklyPercentUsed: Double?
    var nextResetAt: Date?
    var usageStatus: UsageStatus
    var subscriptionStatus: SubscriptionStatus
    var sourceConfidence: Double
    var lastSyncedAt: Date?
    var rawExtractedStrings: [String]
}
```

- [ ] **Step 2: Add provider and account models**

Use these implementations:

```swift
// LimitBar/Domain/Provider.swift
import Foundation

struct Provider: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String

    static let codex = Provider(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, name: "Codex")
}
```

```swift
// LimitBar/Domain/Account.swift
import Foundation

struct Account: Identifiable, Codable, Equatable {
    let id: UUID
    var provider: String
    var email: String?
    var label: String?
    var note: String?
    var priority: Int?
}
```

- [ ] **Step 3: Add a JSON-backed snapshot store**

Use this shape in `LimitBar/Services/SnapshotStore.swift`:

```swift
import Foundation

struct PersistedState: Codable, Equatable {
    var accounts: [Account]
    var snapshots: [UsageSnapshot]
}

final class SnapshotStore {
    private let url: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) throws {
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = appSupport.appendingPathComponent("LimitBar", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        self.url = directory.appendingPathComponent("state.json")
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func load() -> PersistedState {
        guard let data = try? Data(contentsOf: url) else {
            return PersistedState(accounts: [], snapshots: [])
        }
        return (try? decoder.decode(PersistedState.self, from: data)) ?? PersistedState(accounts: [], snapshots: [])
    }

    func save(_ state: PersistedState) throws {
        let data = try encoder.encode(state)
        try data.write(to: url, options: .atomic)
    }
}
```

- [ ] **Step 4: Add a round-trip persistence test**

Use this test in `LimitBarTests/SnapshotStoreTests.swift`:

```swift
import Testing
@testable import LimitBar

struct SnapshotStoreTests {
    @Test
    func loadReturnsEmptyStateWhenFileDoesNotExist() throws {
        let store = try SnapshotStore()
        let state = store.load()
        #expect(state.accounts.isEmpty)
        #expect(state.snapshots.isEmpty)
    }
}
```

- [ ] **Step 5: Run tests**

Run:

```bash
xcodebuild test -scheme LimitBar -destination 'platform=macOS'
```

Expected:
- `SnapshotStoreTests` passes;
- build succeeds with codable model types.

- [ ] **Step 6: Commit**

```bash
git add LimitBar LimitBarTests
git commit -m "feat: add domain models and local snapshot persistence"
```

### Task 3: Add Codex Process Detection and Accessibility Text Extraction Spike

**Files:**
- Create: `LimitBar/Services/ProcessWatcher.swift`
- Create: `LimitBar/Services/AccessibilityReader.swift`
- Modify: `LimitBar/App/AppModel.swift`

- [ ] **Step 1: Implement Codex process detection**

Use this implementation in `LimitBar/Services/ProcessWatcher.swift`:

```swift
import AppKit

struct ProcessWatcher {
    func runningCodexApp() -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first {
            ($0.localizedName ?? "").localizedCaseInsensitiveContains("Codex")
        }
    }
}
```

- [ ] **Step 2: Implement accessibility permission and tree extraction**

Use this starter in `LimitBar/Services/AccessibilityReader.swift`:

```swift
import ApplicationServices
import AppKit

struct AccessibilityReader {
    func hasPermission() -> Bool {
        AXIsProcessTrusted()
    }

    func promptForPermissionIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func extractStrings(from app: NSRunningApplication) -> [String] {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        return collectStrings(from: appElement)
    }

    private func collectStrings(from element: AXUIElement) -> [String] {
        var results: [String] = []
        if let value = copyAttribute(element, attribute: kAXValueAttribute) {
            results.append(value)
        }
        if let title = copyAttribute(element, attribute: kAXTitleAttribute) {
            results.append(title)
        }
        if let description = copyAttribute(element, attribute: kAXDescriptionAttribute) {
            results.append(description)
        }
        if let children = copyChildren(element) {
            for child in children {
                results.append(contentsOf: collectStrings(from: child))
            }
        }
        return results.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func copyAttribute(_ element: AXUIElement, attribute: String) -> String? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success else { return nil }
        return value as? String
    }

    private func copyChildren(_ element: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
        guard error == .success else { return nil }
        return value as? [AXUIElement]
    }
}
```

- [ ] **Step 3: Wire the spike into `AppModel`**

Update `LimitBar/App/AppModel.swift` to:

```swift
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var compactLabel: String = "--"
    @Published var codexRunning: Bool = false
    @Published var lastRefreshAt: Date?
    @Published var rawStrings: [String] = []

    private let processWatcher = ProcessWatcher()
    private let accessibilityReader = AccessibilityReader()

    func refreshNow() {
        lastRefreshAt = Date()

        guard accessibilityReader.hasPermission() else {
            accessibilityReader.promptForPermissionIfNeeded()
            compactLabel = "AX!"
            codexRunning = false
            rawStrings = []
            return
        }

        guard let codex = processWatcher.runningCodexApp() else {
            codexRunning = false
            compactLabel = "--"
            rawStrings = []
            return
        }

        codexRunning = true
        rawStrings = accessibilityReader.extractStrings(from: codex)
        compactLabel = rawStrings.isEmpty ? "No data" : "Read OK"
    }
}
```

- [ ] **Step 4: Expose the captured text in the dropdown**

Add this block to `LimitBar/UI/MenuBarRootView.swift` under the refresh button:

```swift
if !appModel.rawStrings.isEmpty {
    Divider()
    Text("Captured strings")
        .font(.headline)
    ScrollView {
        LazyVStack(alignment: .leading, spacing: 6) {
            ForEach(appModel.rawStrings, id: \.self) { value in
                Text(value)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    .frame(maxHeight: 180)
}
```

- [ ] **Step 5: Run the spike manually**

Manual verification flow:

```text
1. Launch Codex.
2. Open the screen that visibly shows usage/reset.
3. Launch LimitBar.
4. Grant Accessibility permission.
5. Click “Refresh now”.
6. Inspect whether the relevant strings are visible in the dropdown.
```

Expected:
- app can detect Codex;
- raw strings populate;
- at least some usage/reset/account text is visible.

- [ ] **Step 6: Commit**

```bash
git add LimitBar
git commit -m "feat: add codex accessibility extraction spike"
```

### Task 4: Build the Parser and Status Mapping

**Files:**
- Create: `LimitBar/Support/ParserPatterns.swift`
- Create: `LimitBar/Services/UsageParser.swift`
- Create: `LimitBarTests/UsageParserTests.swift`
- Create: `LimitBarTests/Fixtures/codex-cooldown.txt`
- Create: `LimitBarTests/Fixtures/codex-available.txt`

- [ ] **Step 1: Add central parser patterns**

Use this file in `LimitBar/Support/ParserPatterns.swift`:

```swift
import Foundation

enum ParserPatterns {
    static let email = #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#
    static let percentage = #"(\d{1,3})\s*%"#
    static let resetPhraseCandidates = [
        "resets in",
        "available in",
        "resets at",
        "available at"
    ]
}
```

- [ ] **Step 2: Implement a first-pass parser**

Use this implementation in `LimitBar/Services/UsageParser.swift`:

```swift
import Foundation

struct ParsedUsageResult: Equatable {
    var accountIdentifier: String?
    var dailyPercentUsed: Double?
    var weeklyPercentUsed: Double?
    var nextResetAt: Date?
    var status: UsageStatus
    var confidence: Double
}

struct UsageParser {
    func parse(strings: [String], now: Date = .now) -> ParsedUsageResult {
        let joined = strings.joined(separator: "\n")
        let lowered = joined.lowercased()

        let accountIdentifier = firstMatch(in: joined, pattern: ParserPatterns.email)
        let percentages = allPercentages(in: joined)

        let status: UsageStatus
        if lowered.contains("cooldown") || lowered.contains("available in") || lowered.contains("resets in") {
            status = .coolingDown
        } else if lowered.contains("limit reached") || lowered.contains("exhausted") {
            status = .exhausted
        } else if !strings.isEmpty {
            status = .available
        } else {
            status = .unknown
        }

        var confidence = 0.0
        if accountIdentifier != nil { confidence += 0.35 }
        if !percentages.isEmpty { confidence += 0.25 }
        if ParserPatterns.resetPhraseCandidates.contains(where: lowered.contains) { confidence += 0.25 }
        if status != .unknown { confidence += 0.15 }

        return ParsedUsageResult(
            accountIdentifier: accountIdentifier,
            dailyPercentUsed: percentages.first,
            weeklyPercentUsed: percentages.count > 1 ? percentages[1] : nil,
            nextResetAt: nil,
            status: status,
            confidence: min(confidence, 1.0)
        )
    }

    private func firstMatch(in source: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(source.startIndex..., in: source)
        guard let match = regex.firstMatch(in: source, options: [], range: range),
              let matchRange = Range(match.range, in: source) else {
            return nil
        }
        return String(source[matchRange])
    }

    private func allPercentages(in source: String) -> [Double] {
        guard let regex = try? NSRegularExpression(pattern: ParserPatterns.percentage) else {
            return []
        }
        let range = NSRange(source.startIndex..., in: source)
        return regex.matches(in: source, options: [], range: range).compactMap {
            guard $0.numberOfRanges > 1,
                  let valueRange = Range($0.range(at: 1), in: source) else {
                return nil
            }
            return Double(source[valueRange])
        }
    }
}
```

- [ ] **Step 3: Add parser tests against fixture samples**

Use this test file in `LimitBarTests/UsageParserTests.swift`:

```swift
import Foundation
import Testing
@testable import LimitBar

struct UsageParserTests {
    @Test
    func parseCooldownSampleReturnsCoolingDownStatus() throws {
        let parser = UsageParser()
        let sample = [
            "user@example.com",
            "Daily usage 84%",
            "Available in 1h 20m"
        ]

        let result = parser.parse(strings: sample)

        #expect(result.accountIdentifier == "user@example.com")
        #expect(result.dailyPercentUsed == 84)
        #expect(result.status == .coolingDown)
        #expect(result.confidence > 0.7)
    }

    @Test
    func parseUnknownSampleReturnsUnknownWhenStringsAreEmpty() {
        let parser = UsageParser()
        let result = parser.parse(strings: [])

        #expect(result.status == .unknown)
        #expect(result.confidence == 0)
    }
}
```

- [ ] **Step 4: Run parser tests**

Run:

```bash
xcodebuild test -scheme LimitBar -destination 'platform=macOS' -only-testing:LimitBarTests/UsageParserTests
```

Expected:
- parser tests pass;
- status mapping is deterministic.

- [ ] **Step 5: Commit**

```bash
git add LimitBar LimitBarTests
git commit -m "feat: add codex usage parser and status mapping"
```

### Task 5: Connect Parsing, Persistence, and Adaptive Polling

**Files:**
- Create: `LimitBar/App/PollingCoordinator.swift`
- Modify: `LimitBar/App/AppModel.swift`
- Modify: `LimitBar/UI/MenuBarRootView.swift`
- Create: `LimitBar/Support/DateFormatting.swift`
- Test: `LimitBarTests/AppModelTests.swift`

- [ ] **Step 1: Add adaptive polling intervals**

Use this implementation in `LimitBar/App/PollingCoordinator.swift`:

```swift
import Foundation

struct PollingCoordinator {
    func interval(codexRunning: Bool) -> TimeInterval {
        codexRunning ? 15 : 60
    }
}
```

- [ ] **Step 2: Expand `AppModel` to parse and persist snapshots**

Add these properties and refresh flow:

```swift
@Published var accounts: [Account] = []
@Published var snapshots: [UsageSnapshot] = []

private let parser = UsageParser()
private let pollingCoordinator = PollingCoordinator()
private let store: SnapshotStore? = try? SnapshotStore()
private var timerTask: Task<Void, Never>?
```

Inside `refreshNow()` after `rawStrings = ...`:

```swift
let parsed = parser.parse(strings: rawStrings)
let accountId = upsertAccount(identifier: parsed.accountIdentifier)
let snapshot = UsageSnapshot(
    id: UUID(),
    accountId: accountId,
    dailyPercentUsed: parsed.dailyPercentUsed,
    weeklyPercentUsed: parsed.weeklyPercentUsed,
    nextResetAt: parsed.nextResetAt,
    usageStatus: parsed.status,
    subscriptionStatus: .unknown,
    sourceConfidence: parsed.confidence,
    lastSyncedAt: Date(),
    rawExtractedStrings: rawStrings
)
snapshots = snapshots.filter { $0.accountId != accountId } + [snapshot]
persist()
compactLabel = compactLabelText(for: snapshot)
```

Add helper methods:

```swift
private func upsertAccount(identifier: String?) -> UUID {
    if let identifier,
       let existing = accounts.first(where: { $0.email == identifier || $0.label == identifier }) {
        return existing.id
    }

    let account = Account(
        id: UUID(),
        provider: Provider.codex.name,
        email: identifier?.contains("@") == true ? identifier : nil,
        label: identifier?.contains("@") == true ? nil : identifier,
        note: nil,
        priority: nil
    )
    accounts.append(account)
    return account.id
}

private func persist() {
    try? store?.save(PersistedState(accounts: accounts, snapshots: snapshots))
}

private func compactLabelText(for snapshot: UsageSnapshot) -> String {
    if let nextResetAt = snapshot.nextResetAt {
        return countdownString(until: nextResetAt)
    }
    if let daily = snapshot.dailyPercentUsed {
        return "D\(Int(daily))"
    }
    return snapshot.usageStatus == .unknown ? "--" : "OK"
}
```

- [ ] **Step 3: Add formatting helpers**

Use this file in `LimitBar/Support/DateFormatting.swift`:

```swift
import Foundation

func countdownString(until date: Date, now: Date = .now) -> String {
    let remaining = max(0, Int(date.timeIntervalSince(now)))
    let hours = remaining / 3600
    let minutes = (remaining % 3600) / 60
    return "\(hours)h \(minutes)m"
}
```

- [ ] **Step 4: Show accounts and snapshots in the dropdown**

Add this section to `LimitBar/UI/MenuBarRootView.swift`:

```swift
if !appModel.accounts.isEmpty {
    Divider()
    Text("Accounts")
        .font(.headline)
    ForEach(appModel.accounts) { account in
        let snapshot = appModel.snapshots.last { $0.accountId == account.id }
        VStack(alignment: .leading, spacing: 4) {
            Text(account.email ?? account.label ?? "Unknown account")
            Text(snapshot?.usageStatus.rawValue ?? "unknown")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

- [ ] **Step 5: Add a basic `AppModel` test**

Use this starter in `LimitBarTests/AppModelTests.swift`:

```swift
import Testing
@testable import LimitBar

@MainActor
struct AppModelTests {
    @Test
    func compactLabelFallsBackToDashForUnknownState() {
        let model = AppModel()
        #expect(model.compactLabel == "--")
    }
}
```

- [ ] **Step 6: Run tests and manual smoke check**

Run:

```bash
xcodebuild test -scheme LimitBar -destination 'platform=macOS'
```

Manual expected behavior:
- accounts list appears after refreshes;
- latest snapshot replaces older data for the same account;
- compact label updates.

- [ ] **Step 7: Commit**

```bash
git add LimitBar LimitBarTests
git commit -m "feat: connect parser persistence and adaptive polling"
```

### Task 6: Add Notifications and Settings for MVP Completion

**Files:**
- Create: `LimitBar/Services/NotificationManager.swift`
- Create: `LimitBar/UI/SettingsView.swift`
- Modify: `LimitBar/LimitBarApp.swift`
- Modify: `LimitBar/UI/MenuBarRootView.swift`

- [ ] **Step 1: Implement notification permission and scheduling**

Use this implementation in `LimitBar/Services/NotificationManager.swift`:

```swift
import Foundation
import UserNotifications

final class NotificationManager {
    func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func scheduleCooldownReadyNotification(accountName: String, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Account available again"
        content.body = "\(accountName) should be ready to use."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, date.timeIntervalSinceNow),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "cooldown-\(accountName)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }
}
```

- [ ] **Step 2: Add a real settings window**

Use this view in `LimitBar/UI/SettingsView.swift`:

```swift
import SwiftUI

struct SettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("pollingWhenRunning") private var pollingWhenRunning = 15.0
    @AppStorage("pollingWhenClosed") private var pollingWhenClosed = 60.0

    var body: some View {
        Form {
            Toggle("Notifications", isOn: $notificationsEnabled)
            Stepper("Polling when Codex is running: \(Int(pollingWhenRunning))s", value: $pollingWhenRunning, in: 5...60, step: 5)
            Stepper("Polling when Codex is closed: \(Int(pollingWhenClosed))s", value: $pollingWhenClosed, in: 30...300, step: 15)
        }
        .padding()
        .frame(width: 420)
    }
}
```

- [ ] **Step 3: Wire settings into the app**

Update `LimitBar/LimitBarApp.swift`:

```swift
Settings {
    SettingsView()
}
```

Update `LimitBar/UI/MenuBarRootView.swift` to include:

```swift
Button("Open Settings") {
    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
}
```

- [ ] **Step 4: Schedule notifications only when reset time becomes known**

Inside `AppModel`, after snapshot creation:

```swift
if let nextResetAt = snapshot.nextResetAt,
   let account = accounts.first(where: { $0.id == accountId }) {
    let accountName = account.email ?? account.label ?? "Account"
    NotificationManager().scheduleCooldownReadyNotification(accountName: accountName, at: nextResetAt)
}
```

- [ ] **Step 5: Manual MVP verification**

Verify:

```text
1. Menu bar item launches.
2. Codex detection works.
3. Accessibility permission flow works.
4. Raw text is captured.
5. Parser maps at least one real state.
6. Snapshot persists across relaunch.
7. Settings open.
8. Notification permission can be requested and a test notification can be scheduled.
```

- [ ] **Step 6: Commit**

```bash
git add LimitBar
git commit -m "feat: add notifications and settings for mvp"
```

## Final Verification Checklist

- [ ] `xcodebuild test -scheme LimitBar -destination 'platform=macOS'`
- [ ] Manual Codex-open refresh test
- [ ] Manual Codex-closed idle test
- [ ] Accessibility permission revoked/regranted test
- [ ] Relaunch persistence test
- [ ] Notification smoke test

## Risks To Revisit During Execution

- Accessibility tree may expose less text than expected; if so, Task 3 becomes a hard product gate.
- `nextResetAt` parsing is intentionally stubbed in the first parser pass; add real time parsing only after collecting samples.
- The initial recursive AX traversal may need cycle/size guards if Codex exposes a large tree.
- Settings opening with `showSettingsWindow:` may require a more explicit app settings presenter depending on target macOS version.

## Recommendation After Task 3

If Task 3 shows weak accessibility coverage, pause before Task 4 and re-scope the product around:
- raw status visibility only;
- manual account labeling;
- no automatic email extraction guarantee.

If Task 3 is successful, continue through Task 6 without broadening scope.
