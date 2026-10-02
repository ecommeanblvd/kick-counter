import Foundation

/// Launch arguments that make UI tests and screenshots deterministic. They only
/// take effect together with `-uiTesting`:
/// - `-fixedNow <ISO8601>` pins the app's clock for the pregnancy and appointment screens.
/// - `-seedDueDate <ISO8601>` stores that due date at launch.
public struct UITestLaunchOptions: Equatable, Sendable {
    public let isUITesting: Bool
    public let fixedNow: Date?
    public let seedDueDate: Date?

    public init(arguments: [String]) {
        isUITesting = arguments.contains("-uiTesting")
        fixedNow = isUITesting ? Self.date(after: "-fixedNow", in: arguments) : nil
        seedDueDate = isUITesting ? Self.date(after: "-seedDueDate", in: arguments) : nil
    }

    private static func date(after flag: String, in arguments: [String]) -> Date? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return try? Date(arguments[index + 1], strategy: .iso8601)
    }
}
