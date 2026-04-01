import Foundation

struct PersistedState: Codable, Equatable {
    var accounts: [Account]
    var snapshots: [UsageSnapshot]
}

final class SnapshotStore {
    private let url: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

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
        self.encoder = Self.makeEncoder()
        self.decoder = Self.makeDecoder()
    }

    init(directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
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
        guard let data = try? Data(contentsOf: url) else {
            return PersistedState(accounts: [], snapshots: [])
        }
        return (try? decoder.decode(PersistedState.self, from: data))
            ?? PersistedState(accounts: [], snapshots: [])
    }

    func save(_ state: PersistedState) throws {
        let data = try encoder.encode(state)
        try data.write(to: url, options: .atomic)
    }

    func reset() throws {
        try save(PersistedState(accounts: [], snapshots: []))
    }
}
