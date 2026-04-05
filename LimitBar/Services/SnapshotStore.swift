import Foundation

struct PersistedState: Codable, Equatable {
    var accounts: [Account]
    var snapshots: [UsageSnapshot]
    var accountMetadata: [AccountMetadata]
    var settings: AppSettingsState

    init(
        accounts: [Account],
        snapshots: [UsageSnapshot],
        accountMetadata: [AccountMetadata] = [],
        settings: AppSettingsState = .default
    ) {
        self.accounts = accounts
        self.snapshots = snapshots
        self.accountMetadata = accountMetadata
        self.settings = settings
    }

    private enum CodingKeys: String, CodingKey {
        case accounts
        case snapshots
        case accountMetadata
        case settings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accounts = try container.decodeIfPresent([Account].self, forKey: .accounts) ?? []
        snapshots = try container.decodeIfPresent([UsageSnapshot].self, forKey: .snapshots) ?? []
        accountMetadata = try container.decodeIfPresent([AccountMetadata].self, forKey: .accountMetadata) ?? []
        settings = try container.decodeIfPresent(AppSettingsState.self, forKey: .settings) ?? .default
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accounts, forKey: .accounts)
        try container.encode(snapshots, forKey: .snapshots)
        try container.encode(accountMetadata, forKey: .accountMetadata)
        try container.encode(settings, forKey: .settings)
    }
}

protocol SnapshotStoring: AnyObject, Sendable {
    var lastLoadIssue: String? { get }
    func load() -> PersistedState
    func save(_ state: PersistedState) throws
    func reset() throws
}

enum SnapshotStoreLoadIssue: LocalizedError {
    case corruptedStateRecovered(backupFilename: String)
    case corruptedStateRecoveryFailed(details: String)

    var errorDescription: String? {
        switch self {
        case .corruptedStateRecovered(let backupFilename):
            return "Local state was corrupted and moved to \(backupFilename). LimitBar started with a clean state."
        case .corruptedStateRecoveryFailed(let details):
            return "Local state was corrupted and could not be recovered safely: \(details)"
        }
    }
}

final class SnapshotStore: @unchecked Sendable {
    private let fileManager: FileManager
    private let url: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private(set) var lastLoadIssue: String?

    init(fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = appSupport.appendingPathComponent("LimitBar", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        self.url = directory.appendingPathComponent("state.json")
        self.encoder = Self.makeEncoder()
        self.decoder = Self.makeDecoder()
    }

    init(directory: URL) throws {
        self.fileManager = .default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        self.url = directory.appendingPathComponent("state.json")
        self.encoder = Self.makeEncoder()
        self.decoder = Self.makeDecoder()
    }

    private static func makeEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private static func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    func load() -> PersistedState {
        lastLoadIssue = nil
        guard let data = try? Data(contentsOf: url) else {
            return PersistedState(accounts: [], snapshots: [])
        }
        do {
            return try decoder.decode(PersistedState.self, from: data)
        } catch {
            lastLoadIssue = recoverCorruptedStateFile(after: error)
            return PersistedState(accounts: [], snapshots: [])
        }
    }

    func save(_ state: PersistedState) throws {
        let data = try encoder.encode(state)
        try data.write(to: url, options: .atomic)
        lastLoadIssue = nil
    }

    func reset() throws {
        try save(PersistedState(accounts: [], snapshots: []))
    }

    private func recoverCorruptedStateFile(after error: any Error) -> String {
        let timestamp = ISO8601DateFormatter().string(from: .now)
            .replacingOccurrences(of: ":", with: "-")
        let backupURL = url.deletingLastPathComponent()
            .appendingPathComponent("state.corrupted.\(timestamp).json")

        do {
            if fileManager.fileExists(atPath: backupURL.path) {
                try fileManager.removeItem(at: backupURL)
            }
            try fileManager.moveItem(at: url, to: backupURL)
            return SnapshotStoreLoadIssue
                .corruptedStateRecovered(backupFilename: backupURL.lastPathComponent)
                .localizedDescription
        } catch {
            return SnapshotStoreLoadIssue
                .corruptedStateRecoveryFailed(details: error.localizedDescription)
                .localizedDescription
        }
    }
}

extension SnapshotStore: SnapshotStoring {}
