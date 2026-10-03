import XCTest

/// Functional checks of the pregnancy features with a pinned clock.
final class PregnancyUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testCounterWeekLineUsesPinnedClockAndSeededDueDate() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openTab(.counter)
        XCTAssertTrue(app.staticTexts["Week 24 + 3 days"].waitForExistence(timeout: 10))
        attachScreenshot(app, "counter-week-24-en")
    }

    @MainActor
    func testEnteringLastPeriodShowsMatchingWeek() {
        let app = XCUIApplication.launchPinned(language: "en")
        let addDates = app.buttons["pregnancyAddDateButton"]
        XCTAssertTrue(addDates.waitForExistence(timeout: 10))
        addDates.tap()

        let lastPeriod = app.segmentedControls.buttons["Last period"]
        XCTAssertTrue(lastPeriod.waitForExistence(timeout: 5))
        lastPeriod.tap()
        let wheels = app.pickerWheels
        XCTAssertTrue(wheels.element(boundBy: 2).waitForExistence(timeout: 5))
        wheels.element(boundBy: 0).adjust(toPickerWheelValue: "July") // en_US order: month, day, year
        wheels.element(boundBy: 1).adjust(toPickerWheelValue: "1")
        wheels.element(boundBy: 2).adjust(toPickerWheelValue: "2026")

        let estimate = app.staticTexts["pregnancyEstimatedDue"]
        XCTAssertTrue(estimate.waitForExistence(timeout: 5))
        XCTAssertTrue(estimate.label.contains("April 7, 2027"), estimate.label)
        app.buttons["pregnancyDateSave"].tap()

        // LMP 2026-07-01 → due 2027-04-07. On 2026-10-02 that is day 93 = 13w2d, 187 days to go.
        let progress = app.descendants(matching: .any)["weekProgressCard"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertTrue(progress.label.contains("Week 13 + 2 days"), progress.label)
        XCTAssertTrue(progress.label.contains("Trimester 1"), progress.label)
        XCTAssertTrue(progress.label.contains("Days to go: 187"), progress.label)
    }

    @MainActor
    func testAddedAppointmentAppearsInUpcoming() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        let card = app.buttons["nextAppointmentCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()

        let add = app.buttons["addAppointmentButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let title = app.textFields["appointmentTitleField"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Glucose test")
        app.buttons["appointmentSaveButton"].tap()

        // Default date is tomorrow 9:00, so it belongs under "Upcoming", above the milestones.
        let row = app.buttons.matching(NSPredicate(format: "identifier == 'appointmentRow' AND label CONTAINS 'Glucose test'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let upcomingHeader = app.staticTexts["upcomingHeader"]
        let milestonesHeader = app.staticTexts["milestonesHeader"]
        XCTAssertTrue(upcomingHeader.exists)
        XCTAssertTrue(milestonesHeader.exists)
        XCTAssertLessThan(upcomingHeader.frame.minY, row.frame.minY)
        XCTAssertLessThan(row.frame.maxY, milestonesHeader.frame.minY)
        XCTAssertFalse(app.staticTexts["pastHeader"].exists)

        // The home card now shows it as the next check-up.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(card.label.contains("Glucose test"), card.label)
    }
}
