import Foundation

/// A stored session: its identity plus a value snapshot of its state.
public struct SessionRecord: Equatable, Sendable {
    public let id: UUID
    public let state: SessionState

    public init(id: UUID, state: SessionState) {
        self.id = id
        self.state = state
    }
}

public struct KickResult: Equatable, Sendable {
    public let record: SessionRecord
    public let outcome: KickOutcome
    public let didStartSession: Bool

    public init(record: SessionRecord, outcome: KickOutcome, didStartSession: Bool) {
        self.record = record
        self.outcome = outcome
        self.didStartSession = didStartSession
    }
}

/// Persistence for counting sessions. Implementations must keep at most one
/// active session and apply `SessionEngine` rules to every change.
@MainActor
public protocol SessionRepository: AnyObject {
    func activeSession() throws -> SessionRecord?
    /// Adds a kick to the active session, starting a new session if none is active.
    func addKick(at now: Date) throws -> KickResult
    func undoLastKick() throws -> SessionRecord?
    func cancelActive(at now: Date) throws -> SessionRecord?
}
