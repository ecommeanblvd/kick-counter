import Foundation
@preconcurrency import UserNotifications
@testable import KickCore

/// Parses an ISO-8601 timestamp such as "2026-09-01T20:00:00Z".
func date(_ iso: String) -> Date {
    try! Date(iso, strategy: .iso8601)
}

var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}

@MainActor
final class FakeNotificationCenter: NotificationCenterClient {
    var added: [UNNotificationRequest] = []
    var removed: [String] = []
    var status: UNAuthorizationStatus = .authorized
    var grantOnRequest = true
    var requestCount = 0

    func add(_ request: UNNotificationRequest) async throws {
        added.removeAll { $0.identifier == request.identifier }
        added.append(request)
    }

    func removePending(ids: [String]) {
        removed.append(contentsOf: ids)
        added.removeAll { ids.contains($0.identifier) }
    }

    func requestAuthorization() async throws -> Bool {
        requestCount += 1
        status = grantOnRequest ? .authorized : .denied
        return grantOnRequest
    }

    func authorizationStatus() async -> UNAuthorizationStatus { status }
}

/// In-memory SessionRepository with the same rules as KickStore.
@MainActor
final class FakeSessionRepository: SessionRepository {
    struct WriteFailed: Error {}

    private(set) var sessions: [UUID: SessionState] = [:]
    private var activeID: UUID?
    var failNextWrite = false

    func activeSession() throws -> SessionRecord? {
        guard let id = activeID, let state = sessions[id] else { return nil }
        return SessionRecord(id: id, state: state)
    }

    func addKick(at now: Date) throws -> KickResult {
        if failNextWrite {
            failNextWrite = false
            throw WriteFailed()
        }
        var didStart = false
        if activeID == nil {
            let id = UUID()
            sessions[id] = SessionState(startedAt: now)
            activeID = id
            didStart = true
        }
        let id = activeID!
        var state = sessions[id]!
        let outcome = SessionEngine.addKick(to: &state, at: now)
        sessions[id] = state
        if state.status != .active { activeID = nil }
        return KickResult(record: SessionRecord(id: id, state: state), outcome: outcome, didStartSession: didStart)
    }

    func undoLastKick() throws -> SessionRecord? {
        guard let id = activeID, var state = sessions[id] else { return nil }
        SessionEngine.undoLastKick(&state)
        sessions[id] = state
        return SessionRecord(id: id, state: state)
    }

    func cancelActive(at now: Date) throws -> SessionRecord? {
        guard let id = activeID, var state = sessions[id] else { return nil }
        SessionEngine.cancel(&state, at: now)
        sessions[id] = state
        activeID = nil
        return SessionRecord(id: id, state: state)
    }
}

@MainActor
final class FakeLiveActivities: LiveActivityManaging {
    var isAvailable = true
    var activeIDs: Set<UUID> = []
    var started: [(id: UUID, startedAt: Date, count: Int)] = []
    var updates: [(count: Int, completedAt: Date?)] = []
    var ended: [TimeInterval] = []
    var endAllCount = 0

    func hasActivity(for sessionID: UUID) -> Bool { activeIDs.contains(sessionID) }

    func start(sessionID: UUID, startedAt: Date, count: Int) async {
        activeIDs.insert(sessionID)
        started.append((sessionID, startedAt, count))
    }

    func update(count: Int, completedAt: Date?) async { updates.append((count, completedAt)) }

    func end(dismissAfter: TimeInterval) async {
        ended.append(dismissAfter)
        activeIDs.removeAll()
    }

    func endAll() async {
        endAllCount += 1
        activeIDs.removeAll()
    }
}

@MainActor
final class TestClock {
    var now: Date
    init(_ now: Date) { self.now = now }
    func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}
