import XCTest

final class KickCounterUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        // Fixed language so assertions can match the accessibility value text.
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        completeOnboarding()
    }

    private func completeOnboarding() {
        let next = app.buttons["onboardingNext"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
        next.tap()
        app.buttons["onboardingAgree"].tap()
    }

    private func tapKick(times: Int) {
        let kick = app.buttons["kickButton"]
        XCTAssertTrue(kick.waitForExistence(timeout: 5))
        for _ in 0..<times {
            kick.tap()
            Thread.sleep(forTimeInterval: 0.6) // stay above the 0.5 s debounce
        }
    }

    /// Accessibility value of the kick button, e.g. "2 of 10 movements".
    private var kickValue: String? {
        app.buttons["kickButton"].value as? String
    }

    @MainActor
    func testCountingTenMovementsShowsCompletionAndHistory() {
        tapKick(times: 10)

        XCTAssertTrue(app.staticTexts["completionTitle"].waitForExistence(timeout: 5))
        app.buttons["completionDone"].tap()

        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.descendants(matching: .any)["sessionRow"].firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testUndoRemovesLastMovement() {
        tapKick(times: 3)
        app.buttons["undoButton"].tap()
        XCTAssertEqual(kickValue, "2 of 10 movements")
    }

    @MainActor
    func testCancelResetsCounter() {
        tapKick(times: 2)
        app.buttons["cancelSessionButton"].tap()
        let confirm = app.sheets.buttons["Cancel session"]
        if confirm.waitForExistence(timeout: 2) {
            confirm.tap()
        } else {
            // Newer iOS versions may render the dialog as a popover rather than a sheet.
            app.buttons.matching(identifier: "Cancel session").element(boundBy: 1).tap()
        }
        // cancelSession() runs in an async Task, so the kick button's accessibility
        // value updates asynchronously after the tap; wait for it instead of reading
        // it immediately (which raced the update and observed the stale count on CI).
        let kick = app.buttons["kickButton"]
        let reset = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "0 of 10 movements"),
            object: kick
        )
        XCTAssertEqual(XCTWaiter().wait(for: [reset], timeout: 5), .completed)
        XCTAssertEqual(kickValue, "0 of 10 movements")
    }

    @MainActor
    func testDebounceIgnoresAccidentalDoubleTap() {
        let kick = app.buttons["kickButton"]
        XCTAssertTrue(kick.waitForExistence(timeout: 5))
        kick.doubleTap()
        XCTAssertEqual(kickValue, "1 of 10 movements")
    }
}
