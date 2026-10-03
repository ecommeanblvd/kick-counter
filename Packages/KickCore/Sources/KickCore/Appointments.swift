import Foundation

/// A check-up the mother added (value snapshot of the SwiftData `Appointment`).
public struct AppointmentRecord: Equatable, Sendable, Identifiable {
    public let id: UUID
    public var date: Date
    public var title: String
    public var note: String
    public var isDone: Bool
    /// The suggested milestone this was created from, if any.
    public var milestoneID: String?

    public init(
        id: UUID = UUID(),
        date: Date,
        title: String,
        note: String = "",
        isDone: Bool = false,
        milestoneID: String? = nil
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.note = note
        self.isDone = isDone
        self.milestoneID = milestoneID
    }
}

public enum AppointmentRepositoryError: Error, Equatable {
    case notFound
}

/// Storage for appointments. Implementations only store: reminders are kept
/// in step by `AppointmentCoordinator`.
@MainActor
public protocol AppointmentRepository: AnyObject {
    func appointment(id: UUID) throws -> AppointmentRecord?
    /// Not done and on or after the start of today, soonest first.
    func upcoming(now: Date) throws -> [AppointmentRecord]
    /// Done, or before today, most recent first.
    func past(now: Date) throws -> [AppointmentRecord]
    func add(_ appointment: AppointmentRecord) throws
    /// Throws `AppointmentRepositoryError.notFound` when no appointment has that id.
    func update(_ appointment: AppointmentRecord) throws
    /// No-op when no appointment has that id (it may already be gone via iCloud).
    func delete(id: UUID) throws
    /// Returns nil when no appointment has that id.
    func markDone(id: UUID) throws -> AppointmentRecord?
}

public enum AppointmentRules {
    /// An appointment stays "upcoming" for the whole day it falls on, so the
    /// mother can still mark it done after the visit.
    public static func isUpcoming(_ appointment: AppointmentRecord, now: Date, calendar: Calendar = .current) -> Bool {
        !appointment.isDone && appointment.date >= calendar.startOfDay(for: now)
    }

    public static func upcoming(_ all: [AppointmentRecord], now: Date, calendar: Calendar = .current) -> [AppointmentRecord] {
        all.filter { isUpcoming($0, now: now, calendar: calendar) }.sorted { $0.date < $1.date }
    }

    public static func past(_ all: [AppointmentRecord], now: Date, calendar: Calendar = .current) -> [AppointmentRecord] {
        all.filter { !isUpcoming($0, now: now, calendar: calendar) }.sorted { $0.date > $1.date }
    }

    /// Whether a day-before reminder should exist (the scheduler still skips
    /// one whose 9:00 has already passed).
    public static func wantsReminder(_ appointment: AppointmentRecord, now: Date) -> Bool {
        !appointment.isDone && appointment.date > now
    }
}
