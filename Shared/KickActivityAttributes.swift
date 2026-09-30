import ActivityKit
import Foundation

struct KickActivityAttributes: ActivityAttributes, Sendable {
    struct ContentState: Codable, Hashable, Sendable {
        var count: Int
        var completedAt: Date?
    }

    var sessionID: UUID
    var startedAt: Date
}
