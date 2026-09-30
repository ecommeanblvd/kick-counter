import Foundation

public struct GestationalWeek: Equatable, Sendable {
    public let weeks: Int
    public let days: Int

    public init(weeks: Int, days: Int) {
        self.weeks = weeks
        self.days = days
    }
}

public enum GestationalAge {
    static let pregnancyLengthDays = 280
    /// Allow up to two weeks past the due date before treating it as implausible.
    static let maxDaysPastDue = 14

    public static func week(dueDate: Date, now: Date, calendar: Calendar = .current) -> GestationalWeek? {
        let components = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: dueDate)
        )
        guard let daysUntilDue = components.day else { return nil }
        let elapsed = pregnancyLengthDays - daysUntilDue
        guard (0...(pregnancyLengthDays + maxDaysPastDue)).contains(elapsed) else { return nil }
        return GestationalWeek(weeks: elapsed / 7, days: elapsed % 7)
    }
}
