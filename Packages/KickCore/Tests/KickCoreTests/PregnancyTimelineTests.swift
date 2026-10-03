import Foundation
import Testing
@testable import KickCore

struct PregnancyTimelineTests {
    let now = date("2026-10-02T12:00:00Z")

    /// A due date that puts `now` exactly `elapsedDays` into the pregnancy.
    private func makeTimeline(elapsedDays: Int) -> PregnancyTimeline? {
        let due = utcCalendar.date(byAdding: .day, value: 280 - elapsedDays, to: now)!
        return PregnancyTimeline(dueDate: due, now: now, calendar: utcCalendar)
    }

    @Test func specExampleIsWeek24Day3With109DaysToGo() throws {
        let timeline = try #require(PregnancyTimeline(dueDate: date("2027-01-19T12:00:00Z"), now: now, calendar: utcCalendar))
        #expect(timeline.week == GestationalWeek(weeks: 24, days: 3))
        #expect(timeline.elapsedDays == 171)
        #expect(timeline.daysRemaining == 109)
        #expect(timeline.trimester == .second)
        #expect(timeline.isPastDue == false)
        #expect(abs(timeline.progress - 171.0 / 280.0) < 0.000_001)
    }

    @Test func trimesterBoundariesAreWeeks13To14And27To28() {
        #expect(makeTimeline(elapsedDays: 97)?.trimester == .first)   // 13w6d
        #expect(makeTimeline(elapsedDays: 98)?.trimester == .second)  // 14w0d
        #expect(makeTimeline(elapsedDays: 195)?.trimester == .second) // 27w6d
        #expect(makeTimeline(elapsedDays: 196)?.trimester == .third)  // 28w0d
        #expect(Trimester(week: 0) == .first)
        #expect(Trimester(week: 44) == .third)
    }

    @Test func dueDateTodayIsWeek40WithNothingLeftButNotPastDue() throws {
        let timeline = try #require(makeTimeline(elapsedDays: 280))
        #expect(timeline.week == GestationalWeek(weeks: 40, days: 0))
        #expect(timeline.daysRemaining == 0)
        #expect(timeline.daysPastDue == 0)
        #expect(timeline.isPastDue == false)
        #expect(timeline.progress == 1)
    }

    @Test func pastDueReportsDaysPastAndFullProgress() throws {
        let timeline = try #require(makeTimeline(elapsedDays: 287))
        #expect(timeline.week == GestationalWeek(weeks: 41, days: 0))
        #expect(timeline.isPastDue)
        #expect(timeline.daysPastDue == 7)
        #expect(timeline.daysRemaining == 0)
        #expect(timeline.progress == 1)
    }

    @Test func implausibleDatesReturnNil() {
        #expect(makeTimeline(elapsedDays: -1) == nil)  // due more than 280 days away
        #expect(makeTimeline(elapsedDays: 315) == nil) // 45w0d
        #expect(makeTimeline(elapsedDays: 0)?.week == GestationalWeek(weeks: 0, days: 0))
        #expect(makeTimeline(elapsedDays: 0)?.progress == 0)
        #expect(makeTimeline(elapsedDays: 314)?.week == GestationalWeek(weeks: 44, days: 6))
    }

    @Test func timeOfDayIsIgnored() throws {
        let timeline = try #require(PregnancyTimeline(
            dueDate: date("2027-01-19T00:01:00Z"), now: date("2026-10-02T23:59:00Z"), calendar: utcCalendar
        ))
        #expect(timeline.week == GestationalWeek(weeks: 24, days: 3))
    }

    @Test func kickCountingStartsAtWeek28() {
        #expect(makeTimeline(elapsedDays: 195)?.isKickCountingWeek == false)
        #expect(makeTimeline(elapsedDays: 196)?.isKickCountingWeek == true)
    }
}
