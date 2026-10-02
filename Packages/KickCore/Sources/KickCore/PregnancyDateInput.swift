import Foundation

public struct PregnancyDateSelection: Equatable, Sendable {
    public var source: PregnancyDateSource
    public var date: Date

    public init(source: PregnancyDateSource, date: Date) {
        self.source = source
        self.date = date
    }
}

/// Limits and defaults for the due date / last period picker. The ranges allow
/// exactly the dates `PregnancyTimeline` accepts today (0w0d…44w6d).
public enum PregnancyDateInput {
    /// Both defaults describe the same pregnancy at 20 weeks.
    static let defaultOffsetDays = 140
    /// Up to 44 weeks 6 days (the last day `PregnancyTimeline` accepts) = 280 + 34 days.
    static let maxDaysPastDue = (PregnancyTimeline.maxWeeks + 1) * 7 - 1 - GestationalAge.pregnancyLengthDays

    public static func range(for source: PregnancyDateSource, now: Date, calendar: Calendar = .current) -> ClosedRange<Date> {
        let today = calendar.startOfDay(for: now)
        func startOfDay(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: today) ?? today
        }
        let length = GestationalAge.pregnancyLengthDays
        switch source {
        case .dueDate:
            return startOfDay(-maxDaysPastDue)...startOfDay(length + 1).addingTimeInterval(-1)
        case .lmp:
            return startOfDay(-(length + maxDaysPastDue))...startOfDay(1).addingTimeInterval(-1)
        }
    }

    public static func clamp(_ date: Date, for source: PregnancyDateSource, now: Date, calendar: Calendar = .current) -> Date {
        let bounds = range(for: source, now: now, calendar: calendar)
        return min(max(date, bounds.lowerBound), bounds.upperBound)
    }

    public static func defaultDate(for source: PregnancyDateSource, now: Date, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: now)
        let offset = source == .dueDate ? defaultOffsetDays : -defaultOffsetDays
        let day = calendar.date(byAdding: .day, value: offset, to: today) ?? today
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    }

    /// Re-expresses the picked date when the mother switches between due date and last period.
    public static func convert(_ date: Date, to source: PregnancyDateSource, now: Date, calendar: Calendar = .current) -> Date {
        let converted = switch source {
        case .lmp: PregnancyDates.lmp(fromDueDate: date, calendar: calendar)
        case .dueDate: PregnancyDates.dueDate(fromLMP: date, calendar: calendar)
        }
        return clamp(converted, for: source, now: now, calendar: calendar)
    }

    public static func initialSelection(for profile: PregnancyProfile, now: Date, calendar: Calendar = .current) -> PregnancyDateSelection {
        if profile.source == .lmp, let lmp = profile.lmpDate {
            return PregnancyDateSelection(source: .lmp, date: clamp(lmp, for: .lmp, now: now, calendar: calendar))
        }
        if let due = profile.dueDate {
            return PregnancyDateSelection(source: .dueDate, date: clamp(due, for: .dueDate, now: now, calendar: calendar))
        }
        return PregnancyDateSelection(source: .dueDate, date: defaultDate(for: .dueDate, now: now, calendar: calendar))
    }
}
