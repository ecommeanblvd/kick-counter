import Foundation

public enum PregnancyDates {
    /// Naegele's rule: due date = first day of the last period + 280 days.
    /// Adds calendar days, so a daylight-saving change never shifts the time of day.
    public static func dueDate(fromLMP lmp: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: GestationalAge.pregnancyLengthDays, to: lmp) ?? lmp
    }

    public static func lmp(fromDueDate dueDate: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: -GestationalAge.pregnancyLengthDays, to: dueDate) ?? dueDate
    }

    /// Midnight starting gestational week `week` of a pregnancy due on `dueDate`.
    public static func startOfWeek(_ week: Int, dueDate: Date, calendar: Calendar = .current) -> Date {
        let due = calendar.startOfDay(for: dueDate)
        return calendar.date(byAdding: .day, value: week * 7 - GestationalAge.pregnancyLengthDays, to: due) ?? due
    }
}
