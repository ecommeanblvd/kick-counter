import Foundation
import KickCore
import SwiftData

/// SwiftData-backed SessionRepository. Enforces "at most one active session".
@MainActor
public final class KickStore: SessionRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func activeSession() throws -> SessionRecord? {
        try activeModel()?.record
    }

    public func addKick(at now: Date) throws -> KickResult {
        let session: KickSession
        let didStart: Bool
        if let existing = try activeModel() {
            session = existing
            didStart = false
        } else {
            session = KickSession(startedAt: now)
            context.insert(session)
            didStart = true
        }
        var state = session.state
        let outcome = SessionEngine.addKick(to: &state, at: now)
        apply(state, to: session)
        try save()
        return KickResult(record: session.record, outcome: outcome, didStartSession: didStart)
    }

    public func undoLastKick() throws -> SessionRecord? {
        guard let session = try activeModel() else { return nil }
        var state = session.state
        guard SessionEngine.undoLastKick(&state) else { return session.record }
        apply(state, to: session)
        try save()
        return session.record
    }

    public func cancelActive(at now: Date) throws -> SessionRecord? {
        guard let session = try activeModel() else { return nil }
        var state = session.state
        SessionEngine.cancel(&state, at: now)
        apply(state, to: session)
        try save()
        return session.record
    }

    private func activeModel() throws -> KickSession? {
        let active = SessionStatus.active.rawValue
        let descriptor = FetchDescriptor<KickSession>(
            predicate: #Predicate { $0.statusRaw == active },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        let sessions = try context.fetch(descriptor)
        guard let newest = sessions.first else { return nil }
        if sessions.count > 1 {
            for duplicate in sessions.dropFirst() {
                duplicate.status = .cancelled
                duplicate.endedAt = duplicate.endedAt ?? newest.startedAt
            }
            try save()
        }
        return newest
    }

    /// Saves the context, rolling back on failure so a failed write (e.g. the
    /// first kick of a new session) doesn't leave a pending, half-applied
    /// session around that later suppresses start side effects.
    private func save() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    /// Writes an engine state back onto the model, adding/removing Kick rows
    /// so that the stored kicks match `state.kicks`.
    private func apply(_ state: SessionState, to session: KickSession) {
        session.status = state.status
        session.endedAt = state.endedAt
        session.exceededThreshold = state.exceededThreshold

        var stored = (session.kicks ?? []).sorted { $0.timestamp < $1.timestamp }
        while stored.count > state.kicks.count {
            let removed = stored.removeLast()
            session.kicks?.removeAll { $0 === removed }
            context.delete(removed)
        }
        for timestamp in state.kicks.dropFirst(stored.count) {
            let kick = Kick(timestamp: timestamp)
            context.insert(kick)
            kick.session = session
        }
    }
}
