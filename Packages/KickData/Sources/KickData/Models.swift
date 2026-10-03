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

/// A check-up the mother added. Synced through iCloud like sessions.
@Model
public final class Appointment {
    public var id: UUID = UUID()
    public var date: Date = Date()
    public var title: String = ""
    public var note: String = ""
    public var isDone: Bool = false
    /// Id of the suggested milestone this was created from, if any.
    public var milestoneID: String?

    public init(record: AppointmentRecord) {
        id = record.id
        date = record.date
        title = record.title
        note = record.note
        isDone = record.isDone
        milestoneID = record.milestoneID
    }

    public var record: AppointmentRecord {
        AppointmentRecord(id: id, date: date, title: title, note: note, isDone: isDone, milestoneID: milestoneID)
    }

    func apply(_ record: AppointmentRecord) {
        date = record.date
        title = record.title
        note = record.note
        isDone = record.isDone
        milestoneID = record.milestoneID
    }
}
