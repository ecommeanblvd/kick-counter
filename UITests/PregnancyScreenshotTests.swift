import XCTest

/// Screenshots of the Pregnancy tab at fixed gestational ages (see `UITestDates`).
final class PregnancyScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private static let homeWeeks = [
        ("12", UITestDates.dueAtWeek12),
        ("24", UITestDates.dueAtWeek24),
        ("38", UITestDates.dueAtWeek38),
    ]

    @MainActor
    func testPregnancyHomeScreens() {
        for (week, dueDate) in Self.homeWeeks {
            for language in ["vi", "en"] {
                for dark in [false, true] {
                    let name = "pregnancy-home-\(week)-\(language)-\(dark ? "dark" : "light")"
                    let app = XCUIApplication.launchPinned(language: language, dark: dark, dueDate: dueDate)
                    XCTAssertTrue(app.descendants(matching: .any)["weekProgressCard"].waitForExistence(timeout: 10), name)
                    attachScreenshot(app, name)
                    if week == "38", language == "vi", !dark {
                        app.swipeUp()
                        XCTAssertTrue(app.buttons["kickCountCard"].waitForExistence(timeout: 5))
                        attachScreenshot(app, "pregnancy-home-38-vi-light-bottom")
                    }
                    app.terminate()
                }
            }
        }
    }

    @MainActor
    func testPastDueScreen() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueSevenDaysAgo)
        let progress = app.descendants(matching: .any)["weekProgressCard"]
        XCTAssertTrue(progress.waitForExistence(timeout: 10))
        XCTAssertTrue(progress.label.contains("Days past your due date: 7"), progress.label)
        attachScreenshot(app, "pregnancy-home-pastdue-en")
    }

    @MainActor
    func testWeekDetailScreens() {
        for (language, dark) in [("vi", false), ("vi", true), ("en", false)] {
            let suffix = "\(language)-\(dark ? "dark" : "light")"
            let app = XCUIApplication.launchPinned(language: language, dark: dark, dueDate: UITestDates.dueAtWeek24)
            let babyCard = app.buttons["babySizeCard"]
            XCTAssertTrue(babyCard.waitForExistence(timeout: 10))
            babyCard.tap()
            XCTAssertTrue(app.descendants(matching: .any)["weekWarnings"].firstMatch.waitForExistence(timeout: 5))
            attachScreenshot(app, "week-24-\(suffix)")
            app.swipeUp()
            attachScreenshot(app, "week-24-warnings-\(suffix)")
            if language == "vi", !dark {
                app.swipeLeft()
                XCTAssertTrue(app.navigationBars.staticTexts["Tuần 25"].waitForExistence(timeout: 5))
                attachScreenshot(app, "week-25-vi-light")
            }
            app.terminate()
        }
    }

    @MainActor
    func testEmptyStateScreens() {
        for (language, dark) in [("vi", false), ("vi", true), ("en", false)] {
            let suffix = "\(language)-\(dark ? "dark" : "light")"
            let app = XCUIApplication.launchPinned(language: language, dark: dark)
            let addDates = app.buttons["pregnancyAddDateButton"]
            XCTAssertTrue(addDates.waitForExistence(timeout: 10))
            attachScreenshot(app, "pregnancy-empty-\(suffix)")
            if language == "vi", !dark {
                addDates.tap()
                XCTAssertTrue(app.buttons["pregnancyDateSave"].waitForExistence(timeout: 5))
                attachScreenshot(app, "pregnancy-date-sheet-from-home-vi")
            }
            app.terminate()
        }
    }
}
