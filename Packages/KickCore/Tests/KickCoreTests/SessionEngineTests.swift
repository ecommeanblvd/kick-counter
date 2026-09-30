import Foundation
import Testing
@testable import KickCore

struct SessionEngineTests {
    let t0 = date("2026-09-01T20:00:00Z")

    private func kick(_ state: inout SessionState, _ times: Int, every seconds: TimeInterval = 60) -> KickOutcome {
        var outcome = KickOutcome.ignoredInactive
        for i in 0..<times {
            outcome = SessionEngine.addKick(to: &state, at: t0.addingTimeInterval(Double(i) * seconds))
        }
        return outcome
    }

    @Test func firstKickIsCounted() {
        var state = SessionState(startedAt: t0)
        #expect(SessionEngine.addKick(to: &state, at: t0) == .added(count: 1))
        #expect(state.count == 1)
        #expect(state.status == .active)
    }

    @Test func tenthKickCompletesSession() {
        var state = SessionState(startedAt: t0)
        let outcome = kick(&state, 10)
        #expect(outcome == .completed(duration: 9 * 60))
        #expect(state.status == .completed)
        #expect(state.endedAt == t0.addingTimeInterval(9 * 60))
        #expect(state.duration == TimeInterval(9 * 60))
        #expect(state.exceededThreshold == false)
    }

    @Test func tapsCloserThanDebounceAreIgnored() {
        var state = SessionState(startedAt: t0)
        _ = SessionEngine.addKick(to: &state, at: t0)
        #expect(SessionEngine.addKick(to: &state, at: t0.addingTimeInterval(0.3)) == .ignoredDebounce)
        #expect(SessionEngine.addKick(to: &state, at: t0.addingTimeInterval(0.5)) == .added(count: 2))
    }

    @Test func kickAfterCompletionIsIgnored() {
        var state = SessionState(startedAt: t0)
        _ = kick(&state, 10)
        #expect(SessionEngine.addKick(to: &state, at: t0.addingTimeInterval(3600)) == .ignoredInactive)
        #expect(state.count == 10)
    }

    @Test func undoRemovesLastKick() {
        var state = SessionState(startedAt: t0)
        _ = kick(&state, 3)
        #expect(SessionEngine.undoLastKick(&state))
        #expect(state.kicks == [t0, t0.addingTimeInterval(60)])
    }

    @Test func undoWithNoKicksDoesNothing() {
        var state = SessionState(startedAt: t0)
        #expect(SessionEngine.undoLastKick(&state) == false)
    }

    @Test func undoAfterCompletionIsNotAllowed() {
        var state = SessionState(startedAt: t0)
        _ = kick(&state, 10)
        #expect(SessionEngine.undoLastKick(&state) == false)
        #expect(state.count == 10)
    }

    @Test func completionAtOrAfterTwoHoursIsFlagged() {
        var state = SessionState(startedAt: t0)
        _ = kick(&state, 9)
        let outcome = SessionEngine.addKick(to: &state, at: t0.addingTimeInterval(SessionRules.overdueThreshold))
        #expect(outcome == .completed(duration: SessionRules.overdueThreshold))
        #expect(state.exceededThreshold)
    }

    @Test func overdueBoundaryIsInclusive() {
        let state = SessionState(startedAt: t0)
        #expect(SessionEngine.isOverdue(state, now: t0.addingTimeInterval(SessionRules.overdueThreshold - 1)) == false)
        #expect(SessionEngine.isOverdue(state, now: t0.addingTimeInterval(SessionRules.overdueThreshold)))
    }

    @Test func completedSessionIsNeverOverdue() {
        var state = SessionState(startedAt: t0)
        _ = kick(&state, 10)
        #expect(SessionEngine.isOverdue(state, now: t0.addingTimeInterval(10 * 3600)) == false)
    }

    @Test func cancelEndsActiveSession() {
        var state = SessionState(startedAt: t0)
        _ = kick(&state, 2)
        SessionEngine.cancel(&state, at: t0.addingTimeInterval(300))
        #expect(state.status == .cancelled)
        #expect(state.endedAt == t0.addingTimeInterval(300))
    }

    @Test func abandonBoundaryIsInclusive() {
        let state = SessionState(startedAt: t0)
        #expect(SessionEngine.isAbandoned(state, now: t0.addingTimeInterval(SessionRules.abandonAfter - 1)) == false)
        #expect(SessionEngine.isAbandoned(state, now: t0.addingTimeInterval(SessionRules.abandonAfter)))
    }

    @Test func completedOrCancelledSessionIsNeverAbandoned() {
        var completed = SessionState(startedAt: t0)
        _ = kick(&completed, 10)
        #expect(SessionEngine.isAbandoned(completed, now: t0.addingTimeInterval(30 * 3600)) == false)

        var cancelled = SessionState(startedAt: t0)
        _ = kick(&cancelled, 2)
        SessionEngine.cancel(&cancelled, at: t0.addingTimeInterval(120))
        #expect(SessionEngine.isAbandoned(cancelled, now: t0.addingTimeInterval(30 * 3600)) == false)
    }

    @Test func elapsedUsesEndDateWhenFinished() {
        var state = SessionState(startedAt: t0)
        #expect(SessionEngine.elapsed(state, now: t0.addingTimeInterval(90)) == 90)
        _ = kick(&state, 10)
        #expect(SessionEngine.elapsed(state, now: t0.addingTimeInterval(99_999)) == 9 * 60)
    }
}
