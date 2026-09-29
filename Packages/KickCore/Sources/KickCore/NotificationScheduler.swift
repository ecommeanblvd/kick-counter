import Foundation
import OSLog
@preconcurrency import UserNotifications

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "notifications")

public struct NotificationText: Equatable, Sendable {
    public let title: String
    public let body: String

    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }

    func makeContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        return content
    }
}

/// Seam over UNUserNotificationCenter so scheduling can be unit tested.
@MainActor
public protocol NotificationCenterClient: AnyObject {
    func add(_ request: UNNotificationRequest) async throws
    func removePending(ids: [String])
    func requestAuthorization() async throws -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
}

@MainActor
public final class SystemNotificationCenter: NotificationCenterClient {
    private let center = UNUserNotificationCenter.current()

    public init() {}

    public func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    public func removePending(ids: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    public func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    public func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }
}

@MainActor
public final class NotificationScheduler {
    public static let dailyReminderID = "daily-reminder"

    public static func overdueID(for sessionID: UUID) -> String {
        "overdue-\(sessionID.uuidString)"
    }

    private let center: NotificationCenterClient

    public init(center: NotificationCenterClient) {
        self.center = center
    }

    public func isAuthorized() async -> Bool {
        switch await center.authorizationStatus() {
        case .authorized, .provisional, .ephemeral: true
        default: false
        }
    }

    /// Prompts only if the user has never been asked; otherwise reports the current status.
    public func requestAuthorizationIfNeeded() async -> Bool {
        guard await center.authorizationStatus() == .notDetermined else { return await isAuthorized() }
        do {
            return try await center.requestAuthorization()
        } catch {
            logger.error("Notification authorization failed: \(error.localizedDescription)")
            return false
        }
    }

    public func scheduleDailyReminder(hour: Int, minute: Int, text: NotificationText) async throws {
        center.removePending(ids: [Self.dailyReminderID])
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        try await center.add(UNNotificationRequest(identifier: Self.dailyReminderID, content: text.makeContent(), trigger: trigger))
    }

    public func cancelDailyReminder() {
        center.removePending(ids: [Self.dailyReminderID])
    }

    public func scheduleOverdueAlert(sessionID: UUID, startedAt: Date, now: Date, text: NotificationText) async throws {
        let fireIn = startedAt.addingTimeInterval(SessionRules.overdueThreshold).timeIntervalSince(now)
        guard fireIn > 0 else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireIn, repeats: false)
        try await center.add(UNNotificationRequest(identifier: Self.overdueID(for: sessionID), content: text.makeContent(), trigger: trigger))
    }

    public func cancelOverdueAlert(sessionID: UUID) {
        center.removePending(ids: [Self.overdueID(for: sessionID)])
    }
}
