import Testing
import Foundation
@testable import LimitBar

// Each test gets its own temp directory to avoid file-system races when tests run in parallel.
private func makeTempStore() throws -> SnapshotStore {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent("LimitBarTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    return try SnapshotStore(directory: tmp)
}

struct SnapshotStoreTests {
    @Test
    func loadReturnsEmptyStateWhenFileDoesNotExist() throws {
        let store = try makeTempStore()
        let state = store.load()
        #expect(state.accounts.isEmpty)
        #expect(state.snapshots.isEmpty)
        #expect(state.accountMetadata.isEmpty)
        #expect(state.settings == .default)
    }

    @Test
    func roundTripSavesAndLoadsAccounts() throws {
        let store = try makeTempStore()
        let account = Account(id: UUID(), provider: "Codex", email: "test@example.com", label: nil)
        let state = PersistedState(accounts: [account], snapshots: [])
        try store.save(state)
        let loaded = store.load()
        #expect(loaded.accounts.count == 1)
        #expect(loaded.accounts.first?.email == "test@example.com")
    }

    @Test
    func roundTripSavesAndLoadsSnapshots() throws {
        let store = try makeTempStore()
        let accountId = UUID()
        let snapshot = UsageSnapshot(
            id: UUID(),
            accountId: accountId,
            sessionPercentUsed: 42,
            weeklyPercentUsed: 70,
            nextResetAt: nil,
            subscriptionExpiresAt: nil,
            usageStatus: .available,
            sourceConfidence: 0.8,
            lastSyncedAt: Date(),
            rawExtractedStrings: ["42%"]
        )
        let state = PersistedState(accounts: [], snapshots: [snapshot])
        try store.save(state)
        let loaded = store.load()
        #expect(loaded.snapshots.count == 1)
        #expect(loaded.snapshots.first?.sessionPercentUsed == 42)
        #expect(loaded.snapshots.first?.rawExtractedStrings.isEmpty == true)
    }

    @Test
    func resetWritesEmptyState() throws {
        let store = try makeTempStore()
        let account = Account(id: UUID(), provider: "Codex", email: "x@x.com", label: nil)
        try store.save(PersistedState(accounts: [account], snapshots: []))
        try store.reset()
        let loaded = store.load()
        #expect(loaded.accounts.isEmpty)
        #expect(loaded.snapshots.isEmpty)
        #expect(loaded.accountMetadata.isEmpty)
        #expect(loaded.settings == .default)
    }

    @Test
    func loadMigratesOldStateWithoutMetadataAndSettings() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LimitBarLegacy-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let legacyStore = try SnapshotStore(directory: url)
        let legacyPayload = """
        {
          "accounts" : [
            {
              "email" : "legacy@example.com",
              "id" : "\(UUID().uuidString)",
              "label" : null,
              "provider" : "Codex"
            }
          ],
          "snapshots" : [ ]
        }
        """
        try legacyPayload.data(using: .utf8)?.write(
            to: url.appendingPathComponent("state.json"),
            options: .atomic
        )

        let loaded = legacyStore.load()
        #expect(loaded.accounts.count == 1)
        #expect(loaded.accountMetadata.isEmpty)
        #expect(loaded.settings == .default)
    }
}
