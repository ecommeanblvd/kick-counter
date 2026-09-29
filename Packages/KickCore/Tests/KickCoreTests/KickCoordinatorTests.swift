import Foundation
import Testing
@preconcurrency import UserNotifications
@testable import KickCore

@MainActor
struct KickCoordinatorTests {
    let t0 = date("2026-09-01T20:00:00Z")
    let overdueText = NotificationText(title: "Overdue", body: "Call your doctor")
    let repository: FakeSessionRepository
    let center: FakeNotificationCenter
    let live: FakeLiveActivities
    let clock: TestClock
    let coordinator: KickCoordinator

    init() {
        let repository = FakeSessionRepository()
        let center = FakeNotificationCenter()
        let live = FakeLiveActivities()
        let clock = TestClock(date("2026-09-01T20:00:00Z"))
        self.repository = repository
        self.center = center
        self.live = live
        self.clock = clock
        coordinator = Self.makeCoordinator(repository, center, live, clock)
    }

    private static func makeCoordinator(
        _ repository: FakeSessionRepository,
        _ center: FakeNotificationCenter,
        _ live: FakeLiveActivities,
        _ clock: TestClock
    ) -> KickCoordinator {
        KickCoordinator(
            store: repository,
            notifications: NotificationScheduler(center: center),
            liveActivities: live,
            overdueText: NotificationText(title: "Overdue", body: "Call your doctor"),
            now: { clock.now }
        )
    }

    private func kick(times: Int) async {
        for _ in 0..<times {
            await coordinator.recordKick()
            clock.advance(60)
        }
    }

    @Test func firstKickStartsSessionLiveActivityAndOverdueAlert() async throws {
        let outcome = await coordinator.recordKick()
        #expect(outcome == .added(count: 1))
        let id = try #require(coordinator.activeSessionID)
        #expect(coordinator.activeSession?.count == 1)
        #expect(live.started.count == 1)
        #expect(live.started[0].id == id)
        #expect(center.added.map(\.identifier) == [NotificationScheduler.overdueID(for: id)])
    }

    @Test func liveActivityIsSkippedWhenUnavailable() async {
        live.isAvailable = false
        await coordinator.recordKick()
        #expect(live.started.isEmpty)
        #expect(coordinator.activeSession?.count == 1)
    }

    @Test func overdueAlertIsSkippedWhenNotificationsDenied() async {
        center.status = .denied
        await coordinator.recordKick()
        #expect(center.added.isEmpty)
        #expect(coordinator.activeSession?.count == 1)
    }

    @Test func laterKicksUpdateLiveActivity() async {
        await kick(times: 3)
        #expect(live.updates.map(\.count) == [2, 3])
        #expect(live.updates.allSatisfy { $0.completedAt == nil })
    }

    @Test func tenthKickCompletesAndCleansUp() async throws {
        await kick(times: 9)
        let id = try #require(coordinator.activeSessionID)
        let outcome = await coordinator.recordKick()

        #expect(outcome == .completed(duration: 9 * 60))
        #expect(coordinator.activeSession == nil)
        #expect(coordinator.activeSessionID == nil)
        #expect(coordinator.completedSession?.count == 10)
        #expect(center.removed.contains(NotificationScheduler.overdueID(for: id)))
        #expect(live.updates.last?.sessionID == id)
        #expect(live.updates.last?.count == 10)
        #expect(live.updates.last?.completedAt == t0.addingTimeInterval(9 * 60))
        #expect(live.ended.map(\.sessionID) == [id])
        #expect(live.ended.map(\.dismissAfter) == [KickCoordinator.completedActivityLinger])
    }

    @Test func debouncedTapChangesNothing() async {
        await coordinator.recordKick()
        clock.advance(0.2)
        #expect(await coordinator.recordKick() == .ignoredDebounce)
        #expect(coordinator.activeSession?.count == 1)
        #expect(live.updates.isEmpty)
    }

    @Test func saveFailureIsReported() async {
        repository.failNextWrite = true
        #expect(await coordinator.recordKick() == .ignoredInactive)
        #expect(coordinator.failure == .saveFailed)
        coordinator.clearFailure()
        #expect(coordinator.failure == nil)
    }

    @Test func undoUpdatesStateAndLiveActivity() async {
        await kick(times: 3)
        await coordinator.undo()
        #expect(coordinator.activeSession?.count == 2)
        #expect(live.updates.last?.count == 2)
    }

    @Test func cancelEndsEverything() async throws {
        await kick(times: 2)
        let id = try #require(coordinator.activeSessionID)
        await coordinator.cancelSession()
        #expect(coordinator.activeSession == nil)
        #expect(center.removed.contains(NotificationScheduler.overdueID(for: id)))
        #expect(live.ended.map(\.sessionID) == [id])
        #expect(live.ended.map(\.dismissAfter) == [0])
    }

    @Test func loadRestoresActiveSessionAndRestartsMissingLiveActivity() async {
        await kick(times: 2)
        live.activeIDs.removeAll()   // e.g. user dismissed it, or the app was killed

        let restored = Self.makeCoordinator(repository, center, live, clock)
        await restored.load()
        #expect(restored.activeSession?.count == 2)
        #expect(live.started.count == 2)
        #expect(live.started.last?.count == 2)
    }

    @Test func loadWithoutSessionEndsStrayActivities() async {
        await coordinator.load()
        #expect(live.endAllCount == 1)
    }

    @Test func overdueReflectsElapsedTime() async {
        await coordinator.recordKick()
        #expect(coordinator.isOverdue(at: t0.addingTimeInterval(7199)) == false)
        #expect(coordinator.isOverdue(at: t0.addingTimeInterval(7200)))
    }

    @Test func dailyReminderRequiresAuthorization() async {
        center.status = .notDetermined
        center.grantOnRequest = false
        let ok = await coordinator.setDailyReminder(enabled: true, hour: 20, minute: 0, text: overdueText)
        #expect(ok == false)
        #expect(center.added.isEmpty)
    }

    @Test func dailyReminderSchedulesAndCancels() async {
        #expect(await coordinator.setDailyReminder(enabled: true, hour: 20, minute: 0, text: overdueText))
        #expect(center.added.map(\.identifier) == [NotificationScheduler.dailyReminderID])
        #expect(await coordinator.setDailyReminder(enabled: false, hour: 20, minute: 0, text: overdueText))
        #expect(center.added.isEmpty)
    }

    // MARK: - Fix round 1: re-entrancy safety

    /// Finding 1(a): a non-session-scoped `end` resuming after a new session
    /// started would tear down the new session's activity. With session-scoped
    /// calls, session A's completion, however delayed, must never touch B.
    @Test func completingSessionDoesNotAffectNewlyStartedSession() async throws {
        await kick(times: 9)
        let idA = try #require(coordinator.activeSessionID)

        live.holdUpdate = true
        async let completion: KickOutcome = coordinator.recordKick() // 10th kick: completes A, suspends in `update`
        while !live.updatePending { await Task.yield() }

        clock.advance(60)
        let secondOutcome = await coordinator.recordKick() // starts session B
        let idB = try #require(coordinator.activeSessionID)
        #expect(idB != idA)
        #expect(secondOutcome == .added(count: 1))
        #expect(live.hasActivity(for: idB))

        live.releaseUpdate()
        let outcome = await completion
        #expect(outcome == .completed(duration: 9 * 60))

        #expect(live.hasActivity(for: idB))
        #expect(!live.ended.contains { $0.sessionID == idB })
        #expect(!live.updates.contains { $0.sessionID == idB && $0.completedAt != nil })
    }

    /// Finding 1(b): a kick landing while `start` is in flight used to be
    /// dropped (no activity yet) and never recovered. The re-check after
    /// `start` resumes must push the real count.
    @Test func kickWhileStartIsHeldUpdatesLiveActivityAfterRelease() async throws {
        live.holdStart = true
        async let first: KickOutcome = coordinator.recordKick() // kick 1, suspends in `start`
        while !live.startPending { await Task.yield() }

        clock.advance(1)
        let second = await coordinator.recordKick() // kick 2, arrives while start is in flight
        #expect(second == .added(count: 2))

        live.releaseStart()
        let firstOutcome = await first
        #expect(firstOutcome == .added(count: 1))

        let id = try #require(coordinator.activeSessionID)
        #expect(live.updates.last?.sessionID == id)
        #expect(live.updates.last?.count == 2)
    }

    /// Finding 2: a session that completes while authorization is pending must
    /// not schedule a false overdue alert once authorization finally resolves.
    @Test func sessionCompletingWhileAuthorizationIsHeldSchedulesNoAlert() async throws {
        center.status = .notDetermined
        center.holdRequestAuthorization = true

        async let first: KickOutcome = coordinator.recordKick() // kick 1, suspends requesting authorization
        while !center.requestAuthorizationPending { await Task.yield() }
        let idA = try #require(coordinator.activeSessionID)

        for _ in 0..<9 {
            clock.advance(60)
            await coordinator.recordKick() // kicks 2...10, the 10th completes the session
        }
        #expect(coordinator.activeSession == nil)

        center.releaseRequestAuthorization()
        _ = await first

        #expect(!center.added.contains { $0.identifier == NotificationScheduler.overdueID(for: idA) })
    }

    /// Finding 2: same as above, but the session is cancelled instead of completed.
    @Test func sessionCancelledWhileAuthorizationIsHeldSchedulesNoAlert() async throws {
        center.status = .notDetermined
        center.holdRequestAuthorization = true

        async let first: KickOutcome = coordinator.recordKick() // kick 1, suspends requesting authorization
        while !center.requestAuthorizationPending { await Task.yield() }
        let idA = try #require(coordinator.activeSessionID)

        await coordinator.cancelSession()
        #expect(coordinator.activeSession == nil)

        center.releaseRequestAuthorization()
        _ = await first

        #expect(!center.added.contains { $0.identifier == NotificationScheduler.overdueID(for: idA) })
    }

    /// Finding 3: `load()` must not start a second activity when one already
    /// exists; it should instead push the current count.
    @Test func loadWithExistingActivityUpdatesInsteadOfRestarting() async throws {
        await kick(times: 2)
        let id = try #require(coordinator.activeSessionID)
        let startedCountBefore = live.started.count
        let updatesCountBefore = live.updates.count

        await coordinator.load()

        #expect(live.started.count == startedCountBefore)
        #expect(live.updates.count == updatesCountBefore + 1)
        #expect(live.updates.last?.sessionID == id)
        #expect(live.updates.last?.count == 2)
    }

    /// Finding 3: `load()` must reconcile the overdue alert — (re)scheduling it
    /// for the active session and removing any orphaned `overdue-*` requests.
    @Test func loadSchedulesOverdueAlertAndRemovesOrphans() async throws {
        await kick(times: 1)
        let id = try #require(coordinator.activeSessionID)
        center.added.removeAll() // simulate the alert never having been (re)delivered
        let strayID = NotificationScheduler.overdueID(for: UUID())
        center.added.append(UNNotificationRequest(identifier: strayID, content: UNMutableNotificationContent(), trigger: nil))

        await coordinator.load()

        let addedIDs = Set(center.added.map(\.identifier))
        #expect(addedIDs.contains(NotificationScheduler.overdueID(for: id)))
        #expect(!addedIDs.contains(strayID))
    }

    /// Finding 3: two concurrent `load()` calls must not race each other into
    /// starting two activities for the same missing session.
    @Test func concurrentLoadsStartExactlyOneActivity() async throws {
        await kick(times: 2)
        let id = try #require(coordinator.activeSessionID)
        live.activeIDs.removeAll()
        live.started.removeAll()
        live.holdStart = true

        async let loadA: Void = coordinator.load()
        while !live.startPending { await Task.yield() }
        async let loadB: Void = coordinator.load()

        live.releaseStart()
        _ = await loadA
        _ = await loadB

        #expect(live.started.count == 1)
        #expect(live.started.first?.id == id)
    }

    /// Finding 3: `load()` must never prompt the user for notification
    /// authorization — only (re)schedule when already authorized.
    @Test func loadNeverPromptsForAuthorization() async throws {
        center.status = .notDetermined
        _ = try repository.addKick(at: t0) // seed an active session directly, bypassing the coordinator
        #expect(center.requestCount == 0)

        await coordinator.load()

        #expect(center.requestCount == 0)
    }
}
