import Foundation

struct ParsedUsageResult: Equatable {
    var accountIdentifier: String?
    var sessionPercentUsed: Double?
    var weeklyPercentUsed: Double?
    var nextResetAt: Date?
    var status: UsageStatus
    var confidence: Double
}

struct UsageParser {
    func parse(strings: [String], now: Date = .now) -> ParsedUsageResult {
        let joined = strings.joined(separator: "\n")
        let lowered = joined.lowercased()

        let accountIdentifier = extractEmail(from: joined)
        let (session, weekly) = extractUsagePercentages(from: strings)
        let nextResetAt = extractResetDate(from: lowered, now: now)
        let status = resolveStatus(lowered: lowered, strings: strings)

        var confidence = 0.0
        if accountIdentifier != nil { confidence += 0.35 }
        if session != nil || weekly != nil { confidence += 0.25 }
        if ParserPatterns.resetPhrases.contains(where: { lowered.contains($0) }) { confidence += 0.25 }
        if status != .unknown { confidence += 0.15 }

        return ParsedUsageResult(
            accountIdentifier: accountIdentifier,
            sessionPercentUsed: session,
            weeklyPercentUsed: weekly,
            nextResetAt: nextResetAt,
            status: status,
            confidence: min(confidence, 1.0)
        )
    }

    // MARK: - Extraction

    private func extractEmail(from source: String) -> String? {
        let range = NSRange(source.startIndex..., in: source)
        guard let match = ParserPatterns.emailRegex.firstMatch(in: source, range: range),
              let matchRange = Range(match.range, in: source) else { return nil }
        return String(source[matchRange])
    }

    /// Extracts session and weekly percentages by looking for context keywords near the value.
    /// Falls back to positional order (first = session, second = weekly) if no context found.
    private func extractUsagePercentages(from strings: [String]) -> (session: Double?, weekly: Double?) {
        var session: Double?
        var weekly: Double?

        for line in strings {
            let lower = line.lowercased()
            guard let value = firstPercentage(in: line) else { continue }

            if lower.contains("session") || lower.contains("daily") || lower.contains("day") {
                session = session ?? value
            } else if lower.contains("weekly") || lower.contains("week") {
                weekly = weekly ?? value
            }
        }

        // Fallback: if no context labels found, use all percentages positionally
        if session == nil && weekly == nil {
            let all = allContextualPercentages(from: strings)
            session = all.first
            weekly = all.count > 1 ? all[1] : nil
        }

        return (session, weekly)
    }

    /// Returns percentages only from lines that contain a usage-related keyword.
    private func allContextualPercentages(from strings: [String]) -> [Double] {
        let usageLines = strings.filter { line in
            let lower = line.lowercased()
            return ParserPatterns.usageContextKeywords.contains(where: { lower.contains($0) })
        }
        // If no contextual lines, fall back to all lines to avoid showing nothing
        let source = usageLines.isEmpty ? strings : usageLines
        return source.compactMap { firstPercentage(in: $0) }
    }

    private func firstPercentage(in line: String) -> Double? {
        let range = NSRange(line.startIndex..., in: line)
        guard let match = ParserPatterns.percentageRegex.firstMatch(in: line, range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: line) else { return nil }
        return Double(line[valueRange])
    }

    // MARK: - Status

    private func resolveStatus(lowered: String, strings: [String]) -> UsageStatus {
        if ParserPatterns.exhaustedPhrases.contains(where: { lowered.contains($0) }) {
            return .exhausted
        }
        if ParserPatterns.cooldownPhrases.contains(where: { lowered.contains($0) }) {
            return .coolingDown
        }
        if !strings.isEmpty {
            return .available
        }
        return .unknown
    }

    // MARK: - Reset date

    private func extractResetDate(from lowered: String, now: Date) -> Date? {
        guard let phraseRange = ParserPatterns.resetPhrases
            .compactMap({ lowered.range(of: $0) })
            .first else { return nil }

        let suffix = String(lowered[phraseRange.upperBound...].prefix(40))
        return parseDuration(from: suffix).map { now.addingTimeInterval($0) }
    }

    private func parseDuration(from text: String) -> TimeInterval? {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
        var total: TimeInterval = 0
        var matched = false

        if let h = firstGroupDouble(regex: ParserPatterns.hoursRegex, in: cleaned) {
            total += h * 3600; matched = true
        }
        if let m = firstGroupDouble(regex: ParserPatterns.minutesRegex, in: cleaned) {
            total += m * 60; matched = true
        }
        if let s = firstGroupDouble(regex: ParserPatterns.secondsRegex, in: cleaned) {
            total += s; matched = true
        }

        return matched ? total : nil
    }

    private func firstGroupDouble(regex: NSRegularExpression, in source: String) -> Double? {
        let range = NSRange(source.startIndex..., in: source)
        guard let match = regex.firstMatch(in: source, range: range),
              match.numberOfRanges > 1,
              let groupRange = Range(match.range(at: 1), in: source) else { return nil }
        return Double(source[groupRange])
    }
}
