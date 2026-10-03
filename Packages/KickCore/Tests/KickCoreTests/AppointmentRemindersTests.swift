import Foundation
import Testing
@preconcurrency import UserNotifications
@testable import KickCore

@MainActor
struct AppointmentRemindersTests {
    let center = FakeNotificationCenter()
    let text = NotificationText(title: "Check-up tomorrow", body: "Bring your records")
    let now = date("2026-10-02T12:00:00Z")
    var scheduler: NotificationScheduler { NotificationScheduler(center: center) }

    @Test func remindsAt9OnTheDayBefore() async throws {
        let id = UUID()
        let scheduled = try await scheduler.scheduleAppointmentReminder(
            id: id, date: date("2026-10-20T14:30:00Z"), title: "Anomaly scan", now: now, text: text, calendar: utcCalendar
        )
        #expect(scheduled)
        let request = try #require(center.added.first)
        #expect(request.identifier == "appointment-\(id.uuidString)")
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.repeats == false)
        let components = trigger.dateComponents
        #expect([components.year, components.month, components.day, components.hour, components.minute] == [2026, 10, 19, 9, 0])
        #expect(request.content.title == "Check-up tomorrow")
        #expect(request.content.subtitle == "Anomaly scan")
        #expect(request.content.body == "Bring your records")
    }

    @Test func dayBeforeCrossesMonthBoundary() async throws {
        try await scheduler.scheduleAppointmentReminder(
            id: UUID(), date: date("2026-11-01T08:00:00Z"), title: "Scan", now: now, text: text, calendar: utcCalendar
        )
        let trigger = try #require(center.added.first?.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.dateComponents.month == 10)
        #expect(trigger.dateComponents.day == 31)
    }

    @Test func skippedWhenReminderTimeHasPassed() async throws {
        let id = UUID()
        // Tomorrow 08:00 → reminder today 09:00, already past at 12:00.
        let scheduled = try await scheduler.scheduleAppointmentReminder(
            id: id, date: date("2026-10-03T08:00:00Z"), title: "Scan", now: now, text: text, calendar: utcCalendar
        )
        #expect(scheduled == false)
        #expect(center.added.isEmpty)
        #expect(center.removed == [NotificationScheduler.appointmentReminderID(for: id)])
    }

    @Test func reminderExactlyAtNowIsSkipped() async throws {
        let scheduled = try await scheduler.scheduleAppointmentReminder(
            id: UUID(), date: date("2026-10-03T15:00:00Z"), title: "Scan",
            now: date("2026-10-02T09:00:00Z"), text: text, calendar: utcCalendar
        )
        #expect(scheduled == false)
    }

    @Test func reschedulingReplacesTheReminder() async throws {
        let id = UUID()
        try await scheduler.scheduleAppointmentReminder(id: id, date: date("2026-10-20T10:00:00Z"), title: "Scan", now: now, text: text, calendar: utcCalendar)
        try await scheduler.scheduleAppointmentReminder(id: id, date: date("2026-10-25T10:00:00Z"), title: "Scan", now: now, text: text, calendar: utcCalendar)
        #expect(center.added.count == 1)
        #expect((center.added[0].trigger as? UNCalendarNotificationTrigger)?.dateComponents.day == 24)
    }

    @Test func cancelUsesTheAppointmentID() {
        let id = UUID()
        scheduler.cancelAppointmentReminder(id: id)
        #expect(center.removed == ["appointment-\(id.uuidString)"])
    }

    @Test func pendingIDsListOnlyAppointmentReminders() async throws {
        let a = UUID()
        let b = UUID()
        for id in [a, b] {
            try await scheduler.scheduleAppointmentReminder(id: id, date: date("2026-10-20T10:00:00Z"), title: "Scan", now: now, text: text, calendar: utcCalendar)
        }
        try await scheduler.scheduleDailyReminder(hour: 20, minute: 0, text: text)
        try await scheduler.scheduleOverdueAlert(sessionID: UUID(), startedAt: now, now: now, text: text)
        #expect(await scheduler.pendingAppointmentReminderIDs() == [a, b])
    }

    @Test func deniedOnlyWhenTheUserTurnedNotificationsOff() async {
        center.status = .notDetermined
        #expect(await scheduler.isDenied() == false)
        center.status = .denied
        #expect(await scheduler.isDenied())
        center.status = .authorized
        #expect(await scheduler.isDenied() == false)
    }
}
