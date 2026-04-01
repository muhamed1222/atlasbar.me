import Testing
import Foundation
@testable import LimitBar

struct UsageParserTests {
    let parser = UsageParser()

    @Test
    func parseCooldownSampleReturnsCoolingDownStatus() {
        let strings = [
            "user@example.com",
            "Session usage 84%",
            "Available in 1h 20m"
        ]
        let result = parser.parse(strings: strings)
        #expect(result.accountIdentifier == "user@example.com")
        #expect(result.sessionPercentUsed == 84)
        #expect(result.status == .coolingDown)
        #expect(result.confidence > 0.7)
    }

    @Test
    func parseAvailableSampleReturnsAvailableStatus() {
        let strings = [
            "user@example.com",
            "Session usage 24%",
            "Weekly usage 71%"
        ]
        let result = parser.parse(strings: strings)
        #expect(result.status == .available)
        #expect(result.sessionPercentUsed == 24)
        #expect(result.weeklyPercentUsed == 71)
    }

    @Test
    func parseEmptyStringsReturnsUnknown() {
        let result = parser.parse(strings: [])
        #expect(result.status == .unknown)
        #expect(result.confidence == 0)
        #expect(result.accountIdentifier == nil)
    }

    @Test
    func parseExhaustedPhraseReturnsExhaustedStatus() {
        let result = parser.parse(strings: ["Limit reached", "user@test.com"])
        #expect(result.status == .exhausted)
    }

    @Test
    func parseDurationExtractsNextResetAt() {
        let now = Date(timeIntervalSinceReferenceDate: 0)
        let strings = ["Resets in 1h 30m"]
        let result = parser.parse(strings: strings, now: now)
        let expected = now.addingTimeInterval(1 * 3600 + 30 * 60)
        #expect(result.nextResetAt == expected)
    }

    @Test
    func parseMultiplePercentagesExtractsBothDailyAndWeekly() {
        let strings = ["Session 50%", "Weekly 80%"]
        let result = parser.parse(strings: strings)
        #expect(result.sessionPercentUsed == 50)
        #expect(result.weeklyPercentUsed == 80)
    }

    @Test
    func parseNoEmailReturnsNilIdentifier() {
        let strings = ["Session usage 30%", "Some other text"]
        let result = parser.parse(strings: strings)
        #expect(result.accountIdentifier == nil)
    }
}
