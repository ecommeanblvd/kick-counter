import Foundation
import Testing
@testable import KickCore

struct PregnancyDatesTests {
    @Test func dueDateIsLMPPlus280Days() {
        #expect(PregnancyDates.dueDate(fromLMP: date("2026-07-01T12:00:00Z"), calendar: utcCalendar) == date("2027-04-07T12:00:00Z"))
    }

    @Test func leapDayIsCountedAsACalendarDay() {
        // 2028 is a leap year: Feb 29 falls inside the 280 days.
        #expect(PregnancyDates.dueDate(fromLMP: date("2027-06-01T12:00:00Z"), calendar: utcCalendar) == date("2028-03-07T12:00:00Z"))
    }

    @Test func addsCalendarDaysNotSecondsAcrossDaylightSaving() {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        // 10:00 EST on Jan 1 → 10:00 EDT on Oct 8 (an hour earlier in UTC).
        #expect(PregnancyDates.dueDate(fromLMP: date("2026-01-01T15:00:00Z"), calendar: newYork) == date("2026-10-08T14:00:00Z"))
    }

    @Test func lmpAndDueDateRoundTrip() {
        let lmp = date("2026-04-14T12:00:00Z")
        let due = PregnancyDates.dueDate(fromLMP: lmp, calendar: utcCalendar)
        #expect(due == date("2027-01-19T12:00:00Z"))
        #expect(PregnancyDates.lmp(fromDueDate: due, calendar: utcCalendar) == lmp)
    }

    @Test func startOfWeekIsMidnightOfThatGestationalWeek() throws {
        let due = date("2027-01-19T12:00:00Z")
        let start = PregnancyDates.startOfWeek(24, dueDate: due, calendar: utcCalendar)
        #expect(start == date("2026-09-29T00:00:00Z"))
        let timeline = try #require(PregnancyTimeline(dueDate: due, now: start, calendar: utcCalendar))
        #expect(timeline.week == GestationalWeek(weeks: 24, days: 0))
    }
}
