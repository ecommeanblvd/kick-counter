import Foundation
import Testing
@testable import KickCore

struct AppointmentRulesTests {
    let now = date("2026-10-02T12:00:00Z")

    private func appointment(_ iso: String, isDone: Bool = false) -> AppointmentRecord {
        AppointmentRecord(date: date(iso), title: iso, isDone: isDone)
    }

    @Test func todayAndLaterAreUpcomingUntilDone() {
        #expect(AppointmentRules.isUpcoming(appointment("2026-10-02T08:00:00Z"), now: now, calendar: utcCalendar))
        #expect(AppointmentRules.isUpcoming(appointment("2026-10-20T08:00:00Z"), now: now, calendar: utcCalendar))
        #expect(AppointmentRules.isUpcoming(appointment("2026-10-01T23:00:00Z"), now: now, calendar: utcCalendar) == false)
        #expect(AppointmentRules.isUpcoming(appointment("2026-10-20T08:00:00Z", isDone: true), now: now, calendar: utcCalendar) == false)
    }

    @Test func upcomingIsSoonestFirstAndPastMostRecentFirst() {
        let later = appointment("2026-11-01T08:00:00Z")
        let soon = appointment("2026-10-05T08:00:00Z")
        let lastWeek = appointment("2026-09-25T08:00:00Z")
        let longAgo = appointment("2026-08-01T08:00:00Z")
        let done = appointment("2026-10-10T08:00:00Z", isDone: true)
        let all = [longAgo, later, done, soon, lastWeek]
        #expect(AppointmentRules.upcoming(all, now: now, calendar: utcCalendar) == [soon, later])
        #expect(AppointmentRules.past(all, now: now, calendar: utcCalendar) == [done, lastWeek, longAgo])
    }

    @Test func remindersOnlyForFutureAppointmentsNotDone() {
        #expect(AppointmentRules.wantsReminder(appointment("2026-10-20T08:00:00Z"), now: now))
        #expect(AppointmentRules.wantsReminder(appointment("2026-10-02T08:00:00Z"), now: now) == false)
        #expect(AppointmentRules.wantsReminder(appointment("2026-10-20T08:00:00Z", isDone: true), now: now) == false)
    }
}
