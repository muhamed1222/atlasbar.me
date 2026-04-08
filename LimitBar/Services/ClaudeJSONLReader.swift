import Foundation
import OSLog

private let logger = Logger(subsystem: "me.atlasbar.LimitBar", category: "ClaudeJSONLReader")

struct ClaudeTokenStats: Sendable {
    var totalTokensToday: Int
    var totalTokensThisWeek: Int
    var lastActiveAt: Date?
}

protocol ClaudeJSONLReading: Sendable {
    func readStats() -> ClaudeTokenStats
}

struct ClaudeJSONLReader: ClaudeJSONLReading {
    private static let projectsDirectory = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".claude/projects")

    private struct CachedFileEntries {
        let modificationDate: Date
        let entries: [(tokens: Int, date: Date)]
    }

    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var fileCache: [URL: CachedFileEntries] = [:]

    nonisolated(unsafe) private static let fractionalDateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    nonisolated(unsafe) private static let basicDateFormatter = ISO8601DateFormatter()

    func readStats() -> ClaudeTokenStats {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfWeek = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        ) ?? startOfToday

        var tokensToday = 0
        var tokensThisWeek = 0
        var lastActiveAt: Date?

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: Self.projectsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return ClaudeTokenStats(totalTokensToday: 0, totalTokensThisWeek: 0, lastActiveAt: nil)
        }

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "jsonl" else { continue }

            let mtime = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            let entries = cachedEntries(for: fileURL, mtime: mtime)

            for entry in entries {
                if entry.date >= startOfToday { tokensToday += entry.tokens }
                if entry.date >= startOfWeek { tokensThisWeek += entry.tokens }
                if lastActiveAt == nil || entry.date > lastActiveAt! { lastActiveAt = entry.date }
            }
        }

        logger.debug("Claude tokens: today=\(tokensToday) week=\(tokensThisWeek)")
        return ClaudeTokenStats(
            totalTokensToday: tokensToday,
            totalTokensThisWeek: tokensThisWeek,
            lastActiveAt: lastActiveAt
        )
    }

    private func cachedEntries(for fileURL: URL, mtime: Date?) -> [(tokens: Int, date: Date)] {
        let cached = Self.cacheLock.withLock { Self.fileCache[fileURL] }
        if let mtime, let cached, cached.modificationDate == mtime {
            return cached.entries
        }
        let entries = Self.parseFile(at: fileURL)
        Self.cacheLock.withLock {
            Self.fileCache[fileURL] = CachedFileEntries(
                modificationDate: mtime ?? .distantPast,
                entries: entries
            )
        }
        return entries
    }

    private static func parseFile(at fileURL: URL) -> [(tokens: Int, date: Date)] {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
        var entries: [(tokens: Int, date: Date)] = []

        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  let data = trimmed.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["type"] as? String == "assistant",
                  let message = json["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any] else { continue }

            let input = usage["input_tokens"] as? Int ?? 0
            let output = usage["output_tokens"] as? Int ?? 0
            let cacheCreate = usage["cache_creation_input_tokens"] as? Int ?? 0
            let total = input + output + cacheCreate
            guard total > 0 else { continue }

            guard let timestampStr = json["timestamp"] as? String,
                  let date = parseTimestamp(timestampStr) else { continue }

            entries.append((tokens: total, date: date))
        }
        return entries
    }

    private static func parseTimestamp(_ timestamp: String) -> Date? {
        if let date = fractionalDateFormatter.date(from: timestamp) { return date }
        return basicDateFormatter.date(from: timestamp)
    }
}
