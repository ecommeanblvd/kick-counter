import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "coordinator")

public enum KickFailure: Equatable, Sendable {
    case loadFailed
    case saveFailed
}

/// Single entry point for counting actions, used by the UI and by AddKickIntent.
/// Keeps the repository, the overdue notification and the Live Activity in step.
///
/// Every Live Activity call is scoped to a session id, and every side-effect
/// sequence re-checks `activeSessionID` after each `await` before touching that
/// session's Live Activity or overdue alert again, so a session that completes,
/// is cancelled, or is superseded while a side effect is in flight can't corrupt
/// another session's state (see task-6-fix-round-1.md for the defects this guards
/// against).
@MainActor
@Observable
public final class KickCoordinator {
    public static let completedActivityLinger: TimeInterval = 15 * 60

    public private(set) var activeSession: SessionState?
    public private(set) var activeSessionID: UUID?
    public private(set) var completedSession: SessionState?
    public private(set) var failure: KickFailure?

    private let store: SessionRepository
    private let notifications: NotificationScheduler
    private let liveActivities: LiveActivityManaging
    private let overdueText: NotificationText
    private let now: @MainActor () -> Date

    /// The session whose Live Activity `start` call is currently in flight, so
    /// `load()` never races it into starting a second activity for the same session.
    private var startingSessionID: UUID?
    /// The in-flight `load()` reconciliation, so concurrent callers await the
    /// same run instead of each starting their own.
    private var loadTask: Task<Void, Never>?

    public init(
        store: SessionRepository,
        notifications: NotificationScheduler,
        liveActivities: LiveActivityManaging,
        overdueText: NotificationText,
        now: @escaping @MainActor () -> Date = { Date() }
    ) {
        self.store = store
        self.notifications = notifications
        self.liveActivities = liveActivities
        self.overdueText = overdueText
        self.now = now
    }

    public var liveActivitiesAvailable: Bool { liveActivities.isAvailable }

    /// Refreshes state from the store and reconciles the Live Activity and the
    /// overdue alert. Call on launch and whenever the app becomes active.
    /// Concurrent calls share a single in-flight reconciliation.
    public func load() async {
        if let loadTask {
            await loadTask.value
            return
        }
        let task = Task { await self.performLoad() }
        loadTask = task
        await task.value
        loadTask = nil
    }

    private func performLoad() async {
        do {
            let record = try store.activeSession()
            publish(record)
            if let record {
                let sessionID = record.id
                if liveActivities.isAvailable {
                    if !liveActivities.hasActivity(for: sessionID), startingSessionID != sessionID {
                        await liveActivities.start(sessionID: sessionID, startedAt: record.state.startedAt, count: record.state.count)
                    } else if liveActivities.hasActivity(for: sessionID) {
                        await liveActivities.update(sessionID: sessionID, count: record.state.count, completedAt: nil)
                    }
                }
                await notifications.cancelOverdueAlerts(except: sessionID)
                // Never prompt from load(): only (re)schedule when already authorized.
                if await notifications.isAuthorized() {
                    do {
                        try await notifications.scheduleOverdueAlert(
                            sessionID: sessionID, startedAt: record.state.startedAt, now: now(), text: overdueText
                        )
                    } catch {
                        logger.error("Scheduling overdue alert during load failed: \(error.localizedDescription)")
                    }
                }
            } else {
                await liveActivities.endAll()
                await notifications.cancelOverdueAlerts(except: nil)
            }
        } catch {
            logger.error("Loading active session failed: \(error.localizedDescription)")
            failure = .loadFailed
        }
    }

    @discardableResult
    public func recordKick() async -> KickOutcome {
        let time = now()
        let result: KickResult
        do {
            result = try store.addKick(at: time)
        } catch {
            logger.error("Saving kick failed: \(error.localizedDescription)")
            failure = .saveFailed
            return .ignoredInactive
        }

        let record = result.record
        switch result.outcome {
        case .added(let count):
            publish(record)
            if result.didStartSession {
                await startSideEffects(for: record, at: time)
            } else {
                await liveActivities.update(sessionID: record.id, count: count, completedAt: nil)
            }
        case .completed:
            publish(nil)
            completedSession = record.state
            notifications.cancelOverdueAlert(sessionID: record.id)
            await liveActivities.update(sessionID: record.id, count: record.state.count, completedAt: record.state.endedAt)
            await liveActivities.end(sessionID: record.id, dismissAfter: Self.completedActivityLinger)
        case .ignoredDebounce, .ignoredInactive:
            break
        }
        return result.outcome
    }

    public func undo() async {
        do {
            guard let record = try store.undoLastKick() else { return }
            publish(record)
            await liveActivities.update(sessionID: record.id, count: record.state.count, completedAt: nil)
        } catch {
            logger.error("Undo failed: \(error.localizedDescription)")
            failure = .saveFailed
        }
    }

    public func cancelSession() async {
        do {
            guard let record = try store.cancelActive(at: now()) else { return }
            notifications.cancelOverdueAlert(sessionID: record.id)
            publish(nil)
            await liveActivities.end(sessionID: record.id, dismissAfter: 0)
        } catch {
            logger.error("Cancel failed: \(error.localizedDescription)")
            failure = .saveFailed
        }
    }

    public func dismissCompletion() {
        completedSession = nil
    }

    public func clearFailure() {
        failure = nil
    }

    public func isOverdue(at date: Date) -> Bool {
        activeSession.map { SessionEngine.isOverdue($0, now: date) } ?? false
    }

    /// Returns false if the reminder could not be scheduled (usually: permission denied).
    public func setDailyReminder(enabled: Bool, hour: Int, minute: Int, text: NotificationText) async -> Bool {
        guard enabled else {
            notifications.cancelDailyReminder()
            return true
        }
        guard await notifications.requestAuthorizationIfNeeded() else { return false }
        do {
            try await notifications.scheduleDailyReminder(hour: hour, minute: minute, text: text)
            return true
        } catch {
            logger.error("Scheduling daily reminder failed: \(error.localizedDescription)")
            return false
        }
    }

    public func notificationsAuthorized() async -> Bool {
        await notifications.isAuthorized()
    }

    private func publish(_ record: SessionRecord?) {
        activeSession = record?.state
        activeSessionID = record?.id
    }

    private func startSideEffects(for record: SessionRecord, at time: Date) async {
        let sessionID = record.id

        if liveActivities.isAvailable {
            startingSessionID = sessionID
            await liveActivities.start(sessionID: sessionID, startedAt: record.state.startedAt, count: record.state.count)
            if startingSessionID == sessionID { startingSessionID = nil }

            // A later kick may have landed while `start` was in flight; the Live
            // Activity was requested with a stale count, so push the real one.
            if activeSessionID == sessionID, let current = activeSession?.count, current != record.state.count {
                await liveActivities.update(sessionID: sessionID, count: current, completedAt: nil)
            }
        }

        guard await notifications.requestAuthorizationIfNeeded() else { return }
        // The session may have completed or been cancelled while we waited on
        // (possibly user-facing) authorization; don't schedule a false alert.
        guard activeSessionID == sessionID else { return }
        do {
            try await notifications.scheduleOverdueAlert(
                sessionID: sessionID, startedAt: record.state.startedAt, now: time, text: overdueText
            )
            if activeSessionID != sessionID {
                notifications.cancelOverdueAlert(sessionID: sessionID)
            }
        } catch {
            logger.error("Scheduling overdue alert failed: \(error.localizedDescription)")
        }
    }
}
