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

    /// Refreshes state from the store and reconciles the Live Activity.
    /// Call on launch and whenever the app becomes active.
    public func load() async {
        do {
            let record = try store.activeSession()
            publish(record)
            if let record {
                if liveActivities.isAvailable, !liveActivities.hasActivity(for: record.id) {
                    await liveActivities.start(sessionID: record.id, startedAt: record.state.startedAt, count: record.state.count)
                }
            } else {
                await liveActivities.endAll()
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
                await liveActivities.update(count: count, completedAt: nil)
            }
        case .completed:
            publish(nil)
            completedSession = record.state
            notifications.cancelOverdueAlert(sessionID: record.id)
            await liveActivities.update(count: record.state.count, completedAt: record.state.endedAt)
            await liveActivities.end(dismissAfter: Self.completedActivityLinger)
        case .ignoredDebounce, .ignoredInactive:
            break
        }
        return result.outcome
    }

    public func undo() async {
        do {
            guard let record = try store.undoLastKick() else { return }
            publish(record)
            await liveActivities.update(count: record.state.count, completedAt: nil)
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
            await liveActivities.end(dismissAfter: 0)
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
        if liveActivities.isAvailable {
            await liveActivities.start(sessionID: record.id, startedAt: record.state.startedAt, count: record.state.count)
        }
        guard await notifications.requestAuthorizationIfNeeded() else { return }
        do {
            try await notifications.scheduleOverdueAlert(
                sessionID: record.id, startedAt: record.state.startedAt, now: time, text: overdueText
            )
        } catch {
            logger.error("Scheduling overdue alert failed: \(error.localizedDescription)")
        }
    }
}
