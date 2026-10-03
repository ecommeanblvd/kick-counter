import Foundation
import KickCore

/// The app's "now" for the pregnancy and appointment screens. UI tests pin it with
/// `-uiTesting -fixedNow <ISO8601>` so screenshots are deterministic.
/// `KickCoordinator` never uses it: a frozen clock would debounce every kick after the first.
enum AppClock {
    static let launchOptions = UITestLaunchOptions(arguments: ProcessInfo.processInfo.arguments)

    static func now() -> Date {
        launchOptions.fixedNow ?? Date()
    }
}
