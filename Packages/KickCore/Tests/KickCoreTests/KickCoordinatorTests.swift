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
        #expect(live.updates.last?.count == 10)
        #expect(live.updates.last?.completedAt == t0.addingTimeInterval(9 * 60))
        #expect(live.ended == [KickCoordinator.completedActivityLinger])
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
        #expect(live.ended == [0])
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
}
