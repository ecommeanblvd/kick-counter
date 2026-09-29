import Foundation

enum Formatting {
    /// e.g. "23 min", "1 hr, 5 min", "45 sec" — localized by the system.
    static func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds.rounded())
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2))
    }
}
