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
