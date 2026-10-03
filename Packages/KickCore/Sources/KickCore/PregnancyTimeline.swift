import Foundation

public enum Trimester: Int, Sendable, CaseIterable {
    case first = 1
    case second = 2
    case third = 3

    /// 1: weeks 0–13, 2: weeks 14–27, 3: week 28 onwards.
    public init(week: Int) {
        switch week {
        case ..<14: self = .first
        case 14..<28: self = .second
        default: self = .third
        }
    }
}

/// Where a pregnancy stands on a given day, derived from the due date.
/// `nil` when the due date doesn't describe a pregnancy of 0…44 weeks.
public struct PregnancyTimeline: Equatable, Sendable {
    public static let pregnancyLengthDays = GestationalAge.pregnancyLengthDays
    public static let maxWeeks = 44
    static let kickCountingFromWeek = 28

    public let dueDate: Date
    public let elapsedDays: Int

    public init?(dueDate: Date, now: Date, calendar: Calendar = .current) {
        guard let elapsed = GestationalAge.elapsedDays(dueDate: dueDate, now: now, calendar: calendar),
              (0...(Self.maxWeeks * 7 + 6)).contains(elapsed)
        else { return nil }
        self.dueDate = dueDate
        self.elapsedDays = elapsed
    }

    public var week: GestationalWeek {
        GestationalWeek(weeks: elapsedDays / 7, days: elapsedDays % 7)
    }

    public var trimester: Trimester { Trimester(week: week.weeks) }

    public var daysRemaining: Int { max(0, Self.pregnancyLengthDays - elapsedDays) }

    public var daysPastDue: Int { max(0, elapsedDays - Self.pregnancyLengthDays) }

    public var isPastDue: Bool { daysPastDue > 0 }

    /// 0 on the first day of the last period, 1 on (and after) the due date.
    public var progress: Double { min(1, Double(elapsedDays) / Double(Self.pregnancyLengthDays)) }

    /// From week 28 the home screen suggests a daily kick count.
    public var isKickCountingWeek: Bool { week.weeks >= Self.kickCountingFromWeek }
}
