import Foundation
import Testing
@testable import KickCore

struct GestationalAgeTests {
    @Test func dueDateIn84DaysIsWeek28() {
        let now = date("2026-09-01T10:00:00Z")
        let due = date("2026-11-24T10:00:00Z") // 84 days later → 196 days = 28w0d
        #expect(GestationalAge.week(dueDate: due, now: now, calendar: utcCalendar) == GestationalWeek(weeks: 28, days: 0))
    }

    @Test func partialWeeksReportDays() {
        let now = date("2026-09-01T10:00:00Z")
        let due = date("2026-11-21T10:00:00Z") // 81 days → 199 days = 28w3d
        #expect(GestationalAge.week(dueDate: due, now: now, calendar: utcCalendar) == GestationalWeek(weeks: 28, days: 3))
    }

    @Test func implausibleDueDatesReturnNil() {
        let now = date("2026-09-01T10:00:00Z")
        #expect(GestationalAge.week(dueDate: date("2027-09-01T10:00:00Z"), now: now, calendar: utcCalendar) == nil)
        #expect(GestationalAge.week(dueDate: date("2026-07-01T10:00:00Z"), now: now, calendar: utcCalendar) == nil)
    }
}
