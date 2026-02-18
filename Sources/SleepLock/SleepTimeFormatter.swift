import Foundation

enum SleepTimeFormatter {
    static func remainingInterval(until endDate: Date, now: Date = Date()) -> TimeInterval {
        max(0, endDate.timeIntervalSince(now))
    }

    static func shortLabel(until endDate: Date, now: Date = Date()) -> String {
        shortLabel(remaining: remainingInterval(until: endDate, now: now))
    }

    static func detailedLabel(until endDate: Date, now: Date = Date()) -> String {
        detailedLabel(remaining: remainingInterval(until: endDate, now: now))
    }

    static func shortLabel(remaining: TimeInterval) -> String {
        let totalMinutes = minutesRoundedUp(remaining)
        if totalMinutes >= 60 {
            return "\(totalMinutes / 60)h"
        }
        return "\(totalMinutes)m"
    }

    static func detailedLabel(remaining: TimeInterval) -> String {
        let totalMinutes = minutesRoundedUp(remaining)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        }
        if hours > 0 {
            return "\(hours)h"
        }
        return "\(minutes)m"
    }

    private static func minutesRoundedUp(_ remaining: TimeInterval) -> Int {
        max(1, Int(ceil(max(0, remaining) / 60)))
    }
}
