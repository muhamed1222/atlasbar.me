import Foundation

enum ParserPatterns {
    // Compiled once at startup
    static let emailRegex = try! NSRegularExpression(
        pattern: #"[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}"#,
        options: .caseInsensitive
    )
    // Matches "42%", "42.5 %"
    static let percentageRegex = try! NSRegularExpression(
        pattern: #"(\d{1,3}(?:\.\d+)?)\s*%"#
    )
    // Matches "1h 30m", "45m", "2h", "30s"
    static let hoursRegex   = try! NSRegularExpression(pattern: #"(\d+)\s*h"#)
    static let minutesRegex = try! NSRegularExpression(pattern: #"(\d+)\s*m(?!s)"#)
    static let secondsRegex = try! NSRegularExpression(pattern: #"(\d+)\s*s"#)

    static let resetPhrases = [
        "resets in",
        "available in",
        "resets at",
        "available at",
        "ready in",
        "cooldown ends in"
    ]

    static let cooldownPhrases = [
        "cooldown",
        "available in",
        "resets in",
        "ready in"
    ]

    static let exhaustedPhrases = [
        "limit reached",
        "exhausted",
        "no requests remaining",
        "quota exceeded"
    ]

    static let subscriptionPhrases = [
        "expires on",
        "renews on",
        "subscription ends",
        "plan ends"
    ]

    // Keywords that must appear near a percentage for it to count as usage
    static let usageContextKeywords = [
        "session", "daily", "weekly", "usage", "used", "remaining", "credit", "limit", "quota"
    ]
}
