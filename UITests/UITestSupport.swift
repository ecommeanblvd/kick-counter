import XCTest

/// Fixed dates for deterministic pregnancy UI tests. `fixedNow` is noon UTC so
/// it falls on the same calendar day in any simulator time zone from UTC−11 to UTC+11.
enum UITestDates {
    static let fixedNow = "2026-10-02T12:00:00Z"
    /// 12w0d at `fixedNow`.
    static let dueAtWeek12 = "2027-04-16T12:00:00Z"
    /// 24w3d at `fixedNow`, 109 days to go (the spec's example).
    static let dueAtWeek24 = "2027-01-19T12:00:00Z"
    /// 38w0d at `fixedNow`.
    static let dueAtWeek38 = "2026-10-16T12:00:00Z"
    /// 41w0d at `fixedNow`: 7 days past the due date.
    static let dueSevenDaysAgo = "2026-09-25T12:00:00Z"
}

extension XCUIApplication {
    /// Launches with onboarding skipped and the clock pinned to `UITestDates.fixedNow`,
    /// optionally with a stored due date. Only the pregnancy and appointment screens
    /// (and the Count tab's week line) use the pinned clock; counting kicks uses real time.
    @MainActor
    static func launchPinned(language: String = "en", dark: Bool = false, dueDate: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting", "-skipOnboarding",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", language == "vi" ? "vi_VN" : "en_US",
            "-fixedNow", UITestDates.fixedNow,
        ]
        if let dueDate { app.launchArguments += ["-seedDueDate", dueDate] }
        if dark { app.launchArguments.append("-forceDarkMode") }
        app.launch()
        return app
    }
}

extension XCTestCase {
    /// Attaches a screenshot; CI exports it to build/screenshots/<name>_….png.
    @MainActor
    func attachScreenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

/// Tab order in RootView.
enum AppTab: Int {
    case pregnancy = 0
    case counter
    case history
    case settings
}

extension XCUIApplication {
    func openTab(_ tab: AppTab) {
        let button = tabBars.buttons.element(boundBy: tab.rawValue)
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
    }
}
