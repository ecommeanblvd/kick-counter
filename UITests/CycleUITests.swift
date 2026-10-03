import XCTest

/// Functional checks of trying-to-conceive mode with a pinned clock (2026-10-02)
/// and seeded cycles (see `CycleSeedScenario`).
final class CycleUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Spec §8: logging a positive LH test moves the estimated ovulation day.
    @MainActor
    func testPositiveLHTestMovesOvulation() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "fertile")
        let fertileCard = app.descendants(matching: .any)["cycleFertileCard"]
        XCTAssertTrue(fertileCard.waitForExistence(timeout: 10))
        // Regular 28-day cycles, cycle day 13: calendar ovulation on 10-04.
        XCTAssertTrue(fertileCard.label.contains("Estimated ovulation: 10/04"), fertileCard.label)

        let logToday = app.buttons["cycleLogTodayButton"]
        app.scrollUntilHittable(logToday)
        logToday.tap()
        let positive = app.segmentedControls.buttons["Positive"]
        XCTAssertTrue(positive.waitForExistence(timeout: 5))
        positive.tap()
        app.buttons["dayLogSave"].tap()

        // A positive test today (10-02) puts ovulation on the next day.
        waitForLabel(fertileCard, containing: "Estimated ovulation: 10/03")
        XCTAssertTrue(fertileCard.label.contains("Based on your positive LH test"), fertileCard.label)
    }

    @MainActor
    func testEmptyCycleTabAddsTheLastPeriod() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "empty")
        let add = app.buttons["cycleAddPeriodButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        let wheels = app.pickerWheels
        XCTAssertTrue(wheels.element(boundBy: 2).waitForExistence(timeout: 5))
        wheels.element(boundBy: 0).adjust(toPickerWheelValue: "September") // en_US order: month, day, year
        wheels.element(boundBy: 1).adjust(toPickerWheelValue: "20")
        app.buttons["lastPeriodSave"].tap()

        // 2026-09-20 → 2026-10-02 is cycle day 13.
        let status = app.descendants(matching: .any)["cycleStatusCard"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertTrue(status.label.contains("Day 13 of your cycle"), status.label)
    }

    @MainActor
    func testStartingAPeriodClearsTheLateCard() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "late")
        let late = app.descendants(matching: .any)["cycleLateCard"]
        XCTAssertTrue(late.waitForExistence(timeout: 10))
        XCTAssertTrue(late.label.contains("Your period is 4 days late"), late.label)

        let periodButton = app.buttons["cyclePeriodButton"]
        app.scrollUntilHittable(periodButton)
        XCTAssertEqual(periodButton.label, "Period started today")
        periodButton.tap()

        let status = app.descendants(matching: .any)["cycleStatusCard"]
        waitForLabel(status, containing: "Day 1 of your cycle")
        XCTAssertFalse(late.exists)
        XCTAssertEqual(periodButton.label, "Period ended today")
    }

    /// Spec §6: a temperature outside 35.0–38.5 °C is not saved.
    @MainActor
    func testImplausibleTemperatureIsNotSaved() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "fertile")
        let logToday = app.buttons["cycleLogTodayButton"]
        XCTAssertTrue(logToday.waitForExistence(timeout: 10))
        app.scrollUntilHittable(logToday)
        logToday.tap()

        let field = app.textFields["dayLogBBTField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        // Clear the seeded "36.3", then type an implausible value.
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6) + "40")
        app.buttons["dayLogSave"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["dayLogBBTError"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["dayLogSave"].exists) // the sheet stays open
    }
}
