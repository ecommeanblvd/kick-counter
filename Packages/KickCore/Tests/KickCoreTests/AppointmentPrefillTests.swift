import Foundation
import Testing
@testable import KickCore

struct AppointmentPrefillTests {
    let now = date("2026-10-02T12:00:00Z")   // 24w3d for `due`
    let due = date("2027-01-19T12:00:00Z")

    private func milestone(_ from: Int, _ to: Int) -> Milestone {
        Milestone(
            id: "m-\(from)", fromWeek: from, toWeek: to,
            title: LocalizedText(en: "M", vi: "M"), detail: LocalizedText(en: "D", vi: "D"), reviewed: false
        )
    }

    @Test func newAppointmentsDefaultToTomorrowAt9() {
        #expect(AppointmentPrefill.nextDefaultDate(now: now, calendar: utcCalendar) == date("2026-10-03T09:00:00Z"))
    }

    @Test func futureMilestoneStartsOnItsFirstWeekAt9() {
        // Week 30 starts 70 days before the due date.
        #expect(AppointmentPrefill.suggestedDate(for: milestone(30, 32), dueDate: due, now: now, calendar: utcCalendar)
            == date("2026-11-10T09:00:00Z"))
    }

    @Test func milestoneAlreadyUnderwayFallsBackToTomorrow() {
        #expect(AppointmentPrefill.suggestedDate(for: milestone(24, 28), dueDate: due, now: now, calendar: utcCalendar)
            == date("2026-10-03T09:00:00Z"))
    }

    @Test func withoutDueDateFallsBackToTomorrow() {
        #expect(AppointmentPrefill.suggestedDate(for: milestone(30, 32), dueDate: nil, now: now, calendar: utcCalendar)
            == date("2026-10-03T09:00:00Z"))
    }
}
