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
        if holdRequestAuthorization {
            holdRequestAuthorization = false
            requestAuthorizationPending = true
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                requestAuthorizationContinuations.append(continuation)
            }
            requestAuthorizationPending = false
        }
        requestCount += 1
        status = grantOnRequest ? .authorized : .denied
        return grantOnRequest
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        if holdAuthorizationStatus {
            holdAuthorizationStatus = false
            authorizationStatusPending = true
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                authorizationStatusContinuations.append(continuation)
            }
            authorizationStatusPending = false
        }
        return status
    }

    func pendingRequestIDs() async -> [String] { added.map(\.identifier) }

    /// One-shot gate: the next `authorizationStatus()` call suspends until
    /// `releaseAuthorizationStatus()` is called, simulating an in-flight
    /// authorization check (e.g. `isAuthorized()` during `load()`).
    var holdAuthorizationStatus = false
    private(set) var authorizationStatusPending = false
    private var authorizationStatusContinuations: [CheckedContinuation<Void, Never>] = []

    func releaseAuthorizationStatus() {
        let continuations = authorizationStatusContinuations
        authorizationStatusContinuations.removeAll()
        for continuation in continuations { continuation.resume() }
    }

    /// One-shot gate: the next `requestAuthorization()` call suspends until
    /// `releaseRequestAuthorization()` is called, simulating a permission prompt
    /// the user hasn't answered yet.
    var holdRequestAuthorization = false
    private(set) var requestAuthorizationPending = false
    private var requestAuthorizationContinuations: [CheckedContinuation<Void, Never>] = []

    func releaseRequestAuthorization() {
        let continuations = requestAuthorizationContinuations
        requestAuthorizationContinuations.removeAll()
        for continuation in continuations { continuation.resume() }
    }
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
    /// Calls that found an activity for that session and were applied.
    var updates: [(sessionID: UUID, count: Int, completedAt: Date?)] = []
    var ended: [(sessionID: UUID, dismissAfter: TimeInterval)] = []
    /// Calls that found no activity for that session and were dropped (no-op).
    var droppedUpdates: [(sessionID: UUID, count: Int, completedAt: Date?)] = []
    var droppedEnds: [(sessionID: UUID, dismissAfter: TimeInterval)] = []
    var endAllCount = 0

    /// One-shot gate: the next `start(...)` call suspends until `releaseStart()`
    /// is called, simulating an in-flight ActivityKit request.
    var holdStart = false
    private(set) var startPending = false
    private var startContinuations: [CheckedContinuation<Void, Never>] = []

    func hasActivity(for sessionID: UUID) -> Bool { activeIDs.contains(sessionID) }

    func start(sessionID: UUID, startedAt: Date, count: Int) async {
        if holdStart {
            holdStart = false
            startPending = true
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                startContinuations.append(continuation)
            }
            startPending = false
        }
        activeIDs = activeIDs.filter { $0 == sessionID } // ending activities of any other session
        activeIDs.insert(sessionID)
        started.append((sessionID, startedAt, count))
    }

    func releaseStart() {
        let continuations = startContinuations
        startContinuations.removeAll()
        for continuation in continuations { continuation.resume() }
    }

    /// One-shot gate: the next `update(...)` call suspends until `releaseUpdate()`
    /// is called, simulating an in-flight ActivityKit update.
    var holdUpdate = false
    private(set) var updatePending = false
    private var updateContinuations: [CheckedContinuation<Void, Never>] = []

    func update(sessionID: UUID, count: Int, completedAt: Date?) async {
        if holdUpdate {
            holdUpdate = false
            updatePending = true
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                updateContinuations.append(continuation)
            }
            updatePending = false
        }
        guard activeIDs.contains(sessionID) else {
            droppedUpdates.append((sessionID, count, completedAt))
            return
        }
        updates.append((sessionID, count, completedAt))
    }

    func releaseUpdate() {
        let continuations = updateContinuations
        updateContinuations.removeAll()
        for continuation in continuations { continuation.resume() }
    }

    func end(sessionID: UUID, dismissAfter: TimeInterval) async {
        guard activeIDs.contains(sessionID) else {
            droppedEnds.append((sessionID, dismissAfter))
            return
        }
        ended.append((sessionID, dismissAfter))
        activeIDs.remove(sessionID)
    }

    func endAll() async {
        if holdEndAll {
            holdEndAll = false
            endAllPending = true
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                endAllContinuations.append(continuation)
            }
            endAllPending = false
        }
        endAllCount += 1
        activeIDs.removeAll()
    }

    /// One-shot gate: the next `endAll()` call suspends until `releaseEndAll()`
    /// is called, simulating an in-flight ActivityKit request.
    var holdEndAll = false
    private(set) var endAllPending = false
    private var endAllContinuations: [CheckedContinuation<Void, Never>] = []

    func releaseEndAll() {
        let continuations = endAllContinuations
        endAllContinuations.removeAll()
        for continuation in continuations { continuation.resume() }
    }
}

@MainActor
final class TestClock {
    var now: Date
    init(_ now: Date) { self.now = now }
    func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}
