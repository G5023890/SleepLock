import Foundation
import Testing
@testable import SleepLock

@Test
func remainingIntervalNeverNegative() {
    let now = Date(timeIntervalSince1970: 1_000)
    let past = now.addingTimeInterval(-120)

    #expect(SleepTimeFormatter.remainingInterval(until: past, now: now) == 0)
}

@Test
func shortLabelUsesHoursForSixtyMinutesAndAbove() {
    #expect(SleepTimeFormatter.shortLabel(remaining: 60 * 60) == "1h")
    #expect(SleepTimeFormatter.shortLabel(remaining: 2 * 60 * 60 + 5 * 60) == "2h")
}

@Test
func shortLabelUsesMinutesBelowSixtyMinutes() {
    #expect(SleepTimeFormatter.shortLabel(remaining: 59 * 60) == "59m")
    #expect(SleepTimeFormatter.shortLabel(remaining: 1) == "1m")
}

@Test
func detailedLabelIncludesHoursAndMinutesWhenNeeded() {
    #expect(SleepTimeFormatter.detailedLabel(remaining: 72 * 60) == "1h 12m")
    #expect(SleepTimeFormatter.detailedLabel(remaining: 60 * 60) == "1h")
    #expect(SleepTimeFormatter.detailedLabel(remaining: 25 * 60) == "25m")
}

@Test
func dateBasedHelpersUseAbsoluteWallClockDifference() {
    let now = Date(timeIntervalSince1970: 10_000)
    let end = now.addingTimeInterval(89 * 60)

    #expect(SleepTimeFormatter.shortLabel(until: end, now: now) == "1h")
    #expect(SleepTimeFormatter.detailedLabel(until: end, now: now) == "1h 29m")
}
