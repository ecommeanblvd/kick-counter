import Foundation
import KickCore
import SwiftData

// CloudKit-compatible: every attribute has a default or is optional,
// relationships are optional, and no unique constraints are used.

@Model
public final class KickSession {
    public var id: UUID = UUID()
    public var startedAt: Date = Date()
    public var endedAt: Date?
    public var targetCount: Int = 10
    public var statusRaw: String = "active"
    public var exceededThreshold: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \Kick.session)
    public var kicks: [Kick]? = []

    public init(id: UUID = UUID(), startedAt: Date) {
        self.id = id
        self.startedAt = startedAt
    }

    public var status: SessionStatus {
        get { SessionStatus(rawValue: statusRaw) ?? .cancelled }
        set { statusRaw = newValue.rawValue }
    }

    public var state: SessionState {
        SessionState(
            startedAt: startedAt,
            kicks: (kicks ?? []).map(\.timestamp).sorted(),
            status: status,
            endedAt: endedAt,
            exceededThreshold: exceededThreshold
        )
    }

    public var record: SessionRecord {
        SessionRecord(id: id, state: state)
    }
}

@Model
public final class Kick {
    public var timestamp: Date = Date()
    public var session: KickSession?

    public init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
