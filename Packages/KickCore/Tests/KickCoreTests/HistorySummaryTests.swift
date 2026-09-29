import Foundation
import Testing
@testable import KickCore

struct HistorySummaryTests {
    let now = date("2026-09-14T22:00:00Z")

    private func completed(_ start: String, minutes: Double, exceeded: Bool = false) -> SessionState {
        let startedAt = date(start)
        return SessionState(
            startedAt: startedAt,
            kicks: Array(repeating: startedAt, count: 10),
            status: .completed,
            endedAt: startedAt.addingTimeInterval(minutes * 60),
            exceededThreshold: exceeded
        )
    }

    @Test func usesLatestCompletedSessionPerDay() {
        let sessions = [
            completed("2026-09-14T08:00:00Z", minutes: 40),
            completed("2026-09-14T20:00:00Z", minutes: 15),
        ]
        let result = HistorySummary.daily(sessions, endingAt: now, calendar: utcCalendar)
        #expect(result == [DailySummary(day: date("2026-09-14T00:00:00Z"), minutesToTarget: 15, exceededThreshold: false)])
    }

    @Test func ignoresCancelledAndActiveSessions() {
        let cancelled = SessionState(startedAt: date("2026-09-13T20:00:00Z"), status: .cancelled, endedAt: date("2026-09-13T20:05:00Z"))
        let active = SessionState(startedAt: date("2026-09-14T21:00:00Z"))
        #expect(HistorySummary.daily([cancelled, active], endingAt: now, calendar: utcCalendar).isEmpty)
    }

    @Test func onlyIncludesLastFourteenDaysSortedAscending() {
        let sessions = [
            completed("2026-09-14T20:00:00Z", minutes: 10),
            completed("2026-09-01T20:00:00Z", minutes: 20),       // day 14 of window (inclusive)
            completed("2026-08-31T20:00:00Z", minutes: 30),       // outside window
            completed("2026-09-05T20:00:00Z", minutes: 125, exceeded: true),
        ]
        let result = HistorySummary.daily(sessions, endingAt: now, calendar: utcCalendar)
        #expect(result.map(\.day) == [
            date("2026-09-01T00:00:00Z"), date("2026-09-05T00:00:00Z"), date("2026-09-14T00:00:00Z"),
        ])
        #expect(result[1].exceededThreshold)
        #expect(result[1].minutesToTarget == 125)
    }
}
