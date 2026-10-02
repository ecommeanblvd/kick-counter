import Foundation
import Testing
@testable import KickCore

struct ContentValidatorTests {
    private func issues(_ content: PregnancyContent) -> [ContentIssue] {
        ContentValidator.validate(content, requiredWeeks: 7...9)
    }

    @Test func fixtureIsValid() throws {
        #expect(issues(try fixtureContent()).isEmpty)
    }

    @Test func missingWeekIsReported() throws {
        var content = try fixtureContent()
        content.weeks.removeAll { $0.week == 8 }
        #expect(issues(content).contains(.missingWeek(8)))
    }

    @Test func duplicateAndUnexpectedWeeksAreReported() throws {
        var content = try fixtureContent()
        content.weeks.append(content.weeks[0])
        var extra = content.weeks[2]
        extra.week = 43
        content.weeks.append(extra)
        let found = issues(content)
        #expect(found.contains(.duplicateWeek(7)))
        #expect(found.contains(.unexpectedWeek(43)))
        #expect(found.contains(.weeksOutOfOrder))
    }

    @Test func tooFewItemsPerLanguageIsReported() throws {
        var content = try fixtureContent()
        content.weeks[1].tips.vi = ["Một ý."]
        let found = issues(content)
        #expect(found.contains(.tooFewItems(week: 8, section: "tips", language: .vi, minimum: 2)))
        #expect(found.contains(.translationCountMismatch(week: 8, section: "tips")))
    }

    @Test func everyWeekNeedsAWarning() throws {
        var content = try fixtureContent()
        content.weeks[0].warnings.en = []
        #expect(issues(content).contains(.tooFewItems(week: 7, section: "warnings", language: .en, minimum: 1)))
    }

    @Test func blankTextIsReported() throws {
        var content = try fixtureContent()
        content.weeks[0].baby.en[0] = "   "
        content.weeks[1].size.vi = ""
        let found = issues(content)
        #expect(found.contains(.blankText("week 7 baby.en")))
        #expect(found.contains(.blankText("week 8 size.vi")))
    }

    @Test func measurementsAreRequiredFromWeek8() throws {
        var content = try fixtureContent()
        content.weeks[1].lengthCm = nil
        let found = issues(content)
        #expect(found.contains(.missingMeasurement(week: 8, field: "lengthCm")))
        #expect(!found.contains(.missingMeasurement(week: 7, field: "lengthCm")))
    }

    @Test func decreasingOrNonPositiveMeasurementsAreReported() throws {
        var content = try fixtureContent()
        content.weeks[2].weightG = 0.5
        content.weeks[1].lengthCm = 0
        let found = issues(content)
        #expect(found.contains(.decreasingMeasurement(week: 9, field: "weightG")))
        #expect(found.contains(.nonPositiveMeasurement(week: 8, field: "lengthCm")))
    }

    @Test func invalidMilestoneRangesAreReported() throws {
        var content = try fixtureContent()
        content.milestones[0].fromWeek = 9
        content.milestones[0].toWeek = 8
        content.milestones[1].toWeek = 43
        let found = issues(content)
        #expect(found.contains(.invalidMilestoneRange(id: "m-early")))
        #expect(found.contains(.invalidMilestoneRange(id: "m-late")))
    }

    @Test func duplicateMilestoneIDsAreReported() throws {
        var content = try fixtureContent()
        content.milestones[1].id = "m-early"
        #expect(issues(content).contains(.duplicateMilestoneID("m-early")))
    }

    @Test func blankMilestoneTextIsReported() throws {
        var content = try fixtureContent()
        content.milestones[0].detail.vi = " "
        #expect(issues(content).contains(.blankText("milestone m-early detail.vi")))
    }

    @Test func versionAndSourcesAreChecked() throws {
        var content = try fixtureContent()
        content.version = 2
        content.sources = []
        let found = issues(content)
        #expect(found.contains(.unsupportedVersion(2)))
        #expect(found.contains(.noSources))
    }
}
