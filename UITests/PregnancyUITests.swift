import XCTest

/// Functional checks of the pregnancy features with a pinned clock.
final class PregnancyUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testCounterWeekLineUsesPinnedClockAndSeededDueDate() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        XCTAssertTrue(app.staticTexts["Week 24 + 3 days"].waitForExistence(timeout: 10))
        attachScreenshot(app, "counter-week-24-en")
    }
}
