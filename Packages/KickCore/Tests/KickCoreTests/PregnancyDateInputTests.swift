import Foundation
import Testing
@testable import KickCore

struct PregnancyDateInputTests {
    let now = date("2026-10-02T12:00:00Z")
    let oneDay: TimeInterval = 86_400

    private func timeline(due: Date) -> PregnancyTimeline? {
        PregnancyTimeline(dueDate: due, now: now, calendar: utcCalendar)
    }

    @Test func dueDateRangeCoversExactlyTheValidTimeline() {
        let range = PregnancyDateInput.range(for: .dueDate, now: now, calendar: utcCalendar)
        #expect(range.lowerBound == date("2026-08-29T00:00:00Z"))           // 44w6d today
        #expect(range.upperBound == date("2027-07-09T23:59:59Z"))           // 0w0d today
        #expect(timeline(due: range.lowerBound)?.week == GestationalWeek(weeks: 44, days: 6))
        #expect(timeline(due: range.lowerBound.addingTimeInterval(-oneDay)) == nil)
        #expect(timeline(due: range.upperBound)?.week == GestationalWeek(weeks: 0, days: 0))
        #expect(timeline(due: range.upperBound.addingTimeInterval(1)) == nil)
    }

    @Test func lastPeriodRangeEndsTodayAndCoversTheValidTimeline() {
        let range = PregnancyDateInput.range(for: .lmp, now: now, calendar: utcCalendar)
        #expect(range.upperBound == date("2026-10-02T23:59:59Z"))
        let earliestDue = PregnancyDates.dueDate(fromLMP: range.lowerBound, calendar: utcCalendar)
        #expect(timeline(due: earliestDue)?.week == GestationalWeek(weeks: 44, days: 6))
        let tooEarly = PregnancyDates.dueDate(fromLMP: range.lowerBound.addingTimeInterval(-oneDay), calendar: utcCalendar)
        #expect(timeline(due: tooEarly) == nil)
    }

    @Test func defaultsDescribeTheSamePregnancyAt20Weeks() {
        let due = PregnancyDateInput.defaultDate(for: .dueDate, now: now, calendar: utcCalendar)
        let lmp = PregnancyDateInput.defaultDate(for: .lmp, now: now, calendar: utcCalendar)
        #expect(due == date("2027-02-19T12:00:00Z"))
        #expect(PregnancyDates.dueDate(fromLMP: lmp, calendar: utcCalendar) == due)
        #expect(timeline(due: due)?.week == GestationalWeek(weeks: 20, days: 0))
    }

    @Test func convertKeepsTheSamePregnancy() {
        let lmp = PregnancyDateInput.convert(date("2027-01-19T12:00:00Z"), to: .lmp, now: now, calendar: utcCalendar)
        #expect(lmp == date("2026-04-14T12:00:00Z"))
        #expect(PregnancyDateInput.convert(lmp, to: .dueDate, now: now, calendar: utcCalendar) == date("2027-01-19T12:00:00Z"))
    }

    @Test func clampKeepsDatesInsideThePicker() {
        let dueRange = PregnancyDateInput.range(for: .dueDate, now: now, calendar: utcCalendar)
        let lmpRange = PregnancyDateInput.range(for: .lmp, now: now, calendar: utcCalendar)
        #expect(PregnancyDateInput.clamp(date("2030-01-01T00:00:00Z"), for: .dueDate, now: now, calendar: utcCalendar) == dueRange.upperBound)
        #expect(PregnancyDateInput.clamp(date("2020-01-01T00:00:00Z"), for: .lmp, now: now, calendar: utcCalendar) == lmpRange.lowerBound)
    }

    @Test func initialSelectionFollowsTheStoredProfile() {
        let empty = PregnancyProfile(source: .dueDate, dueDate: nil, lmpDate: nil)
        #expect(PregnancyDateInput.initialSelection(for: empty, now: now, calendar: utcCalendar)
            == PregnancyDateSelection(source: .dueDate, date: date("2027-02-19T12:00:00Z")))

        let due = PregnancyProfile(source: .dueDate, dueDate: date("2027-01-19T12:00:00Z"), lmpDate: nil)
        #expect(PregnancyDateInput.initialSelection(for: due, now: now, calendar: utcCalendar)
            == PregnancyDateSelection(source: .dueDate, date: date("2027-01-19T12:00:00Z")))

        let lmp = PregnancyProfile(source: .lmp, dueDate: date("2027-04-07T12:00:00Z"), lmpDate: date("2026-07-01T12:00:00Z"))
        #expect(PregnancyDateInput.initialSelection(for: lmp, now: now, calendar: utcCalendar)
            == PregnancyDateSelection(source: .lmp, date: date("2026-07-01T12:00:00Z")))
    }
}
