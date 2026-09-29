import ActivityKit
import Foundation

struct KickActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var count: Int
        var completedAt: Date?
    }

    var sessionID: UUID
    var startedAt: Date
}
