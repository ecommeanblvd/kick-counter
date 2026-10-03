import Foundation

/// Dates pre-filled in the "add check-up" sheet.
public enum AppointmentPrefill {
    public static let defaultHour = 9

    /// Tomorrow at 9:00.
    public static func nextDefaultDate(now: Date, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        return calendar.date(bySettingHour: defaultHour, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    /// 9:00 on the first day of the milestone's week range, or tomorrow at
    /// 9:00 when that day has passed (or the due date is unknown).
    public static func suggestedDate(for milestone: Milestone, dueDate: Date?, now: Date, calendar: Calendar = .current) -> Date {
        let earliest = nextDefaultDate(now: now, calendar: calendar)
        guard let dueDate else { return earliest }
        let weekStart = PregnancyDates.startOfWeek(milestone.fromWeek, dueDate: dueDate, calendar: calendar)
        let candidate = calendar.date(bySettingHour: defaultHour, minute: 0, second: 0, of: weekStart) ?? weekStart
        return max(candidate, earliest)
    }
}
