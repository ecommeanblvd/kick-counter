import XCTest

/// Captures screenshots for visual review. CI exports them to build/screenshots,
/// and `scripts/ci-wait.sh` downloads them to ci-artifacts/screenshots.
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func launch(language: String = "vi", dark: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting", "-skipOnboarding",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", language == "vi" ? "vi_VN" : "en_US",
        ]
        if dark { app.launchArguments.append("-forceDarkMode") }
        app.launch()
        return app
    }

    @MainActor
    func snap(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func tapKick(_ app: XCUIApplication, times: Int) {
        let kick = app.buttons["kickButton"]
        XCTAssertTrue(kick.waitForExistence(timeout: 10))
        for _ in 0..<times {
            kick.tap()
            Thread.sleep(forTimeInterval: 0.6) // stay above the 0.5 s debounce
        }
    }

    /// Confirms the cancel-session dialog (its destructive button comes first).
    @MainActor
    func confirmCancel(_ app: XCUIApplication) {
        let sheetButton = app.sheets.buttons.element(boundBy: 0)
        if sheetButton.waitForExistence(timeout: 2) {
            sheetButton.tap()
            return
        }
        // Newer iOS versions may show a popover: its button has the same label.
        let label = app.buttons["cancelSessionButton"].label
        app.buttons.matching(NSPredicate(format: "label == %@", label)).element(boundBy: 1).tap()
    }

    @MainActor
    func testHistoryScreens() {
        for dark in [false, true] {
            let suffix = dark ? "dark" : "light"
            let app = launch(dark: dark)
            tapKick(app, times: 10)
            XCTAssertTrue(app.buttons["completionDone"].waitForExistence(timeout: 5))
            app.buttons["completionDone"].tap()
            tapKick(app, times: 2)
            app.buttons["cancelSessionButton"].tap()
            confirmCancel(app)
            app.tabBars.buttons.element(boundBy: 1).tap()
            XCTAssertTrue(app.descendants(matching: .any)["sessionRow"].firstMatch.waitForExistence(timeout: 5))
            snap(app, "history-\(suffix)")
            app.terminate()
        }
    }

    @MainActor
    func testCounterScreens() {
        for dark in [false, true] {
            let suffix = dark ? "dark" : "light"
            let app = launch(dark: dark)
            tapKick(app, times: 0)
            snap(app, "counter-empty-\(suffix)")
            tapKick(app, times: 3)
            snap(app, "counter-3-\(suffix)")
            tapKick(app, times: 7)
            XCTAssertTrue(app.staticTexts["completionTitle"].waitForExistence(timeout: 5))
            snap(app, "completion-\(suffix)")
            app.terminate()
        }
        let app = launch(language: "en")
        tapKick(app, times: 2)
        snap(app, "counter-2-en")
    }

    @MainActor
    func testOnboardingAndSettingsScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(vi)", "-AppleLocale", "vi_VN"]
        app.launch()

        let next = app.buttons["onboardingNext"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        snap(app, "onboarding-1")
        next.tap()
        snap(app, "onboarding-2")
        next.tap()
        snap(app, "onboarding-3")
        app.buttons["onboardingAgree"].tap()

        app.tabBars.buttons.element(boundBy: 2).tap()
        XCTAssertTrue(app.switches.firstMatch.waitForExistence(timeout: 5))
        snap(app, "settings")
        let dueDateToggle = app.switches["settingsDueDateToggle"] // "Đặt ngày dự sinh"
        XCTAssertTrue(dueDateToggle.waitForExistence(timeout: 5))
        dueDateToggle.tap()
        let dueDateOn = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '1'"), object: dueDateToggle)
        let waitResult = XCTWaiter().wait(for: [dueDateOn], timeout: 5)
        if waitResult != .completed {
            let attachment = XCTAttachment(string: app.debugDescription)
            attachment.name = "settings-due-date-debug"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        snap(app, "settings-due-date")

        app.tabBars.buttons.element(boundBy: 0).tap()
        snap(app, "counter-with-week")
    }
}
