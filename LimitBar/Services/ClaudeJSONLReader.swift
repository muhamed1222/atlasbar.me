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
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return ClaudeTokenStats(totalTokensToday: 0, totalTokensThisWeek: 0, lastActiveAt: nil)
        }

        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoBasic = ISO8601DateFormatter()

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "jsonl" else { continue }
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }

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
                      let date = isoFractional.date(from: timestampStr)
                        ?? isoBasic.date(from: timestampStr) else { continue }

                if date >= startOfToday {
                    tokensToday += total
                }
                if date >= startOfWeek {
                    tokensThisWeek += total
                }
                if lastActiveAt == nil || date > lastActiveAt! {
                    lastActiveAt = date
                }
            }
        }

        logger.debug("Claude tokens: today=\(tokensToday) week=\(tokensThisWeek)")
        return ClaudeTokenStats(
            totalTokensToday: tokensToday,
            totalTokensThisWeek: tokensThisWeek,
            lastActiveAt: lastActiveAt
        )
    }
}
