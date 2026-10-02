import Foundation
import Testing
@testable import KickCore

struct WeeklyContentLibraryTests {
    private func library() throws -> WeeklyContentLibrary {
        WeeklyContentLibrary(document: try fixtureContent())
    }

    @Test func decodesFromJSONData() throws {
        let data = try JSONEncoder().encode(try fixtureContent())
        let library = try WeeklyContentLibrary(data: data)
        #expect(library.document.weeks.map(\.week) == [7, 8, 9])
        #expect(library.sources == ["Fixture source A", "Fixture source B"])
        #expect(library.content(forWeek: 7)?.lengthCm == nil)
        #expect(library.content(forWeek: 8)?.weightG == 1)
    }

    @Test func malformedJSONThrows() {
        #expect(throws: DecodingError.self) {
            try WeeklyContentLibrary(data: Data("{}".utf8))
        }
    }

    @Test func weekLookupClampsTo4Through42() {
        #expect(WeeklyContentLibrary.clampedWeek(1) == 4)
        #expect(WeeklyContentLibrary.clampedWeek(4) == 4)
        #expect(WeeklyContentLibrary.clampedWeek(24) == 24)
        #expect(WeeklyContentLibrary.clampedWeek(42) == 42)
        #expect(WeeklyContentLibrary.clampedWeek(44) == 42)
    }

    @Test func lookupReturnsThatWeek() throws {
        let library = try library()
        #expect(library.content(forWeek: 8)?.size.emoji == "🍒")
        #expect(library.content(forWeek: 5) == nil) // clamped to 5, absent from the fixture
    }

    @Test func displayHonoursReviewedFlag() throws {
        let library = try library()
        let week7 = try #require(library.content(forWeek: 7))
        let week8 = try #require(library.content(forWeek: 8))
        #expect(library.display(forWeek: 7, visibility: .reviewedOnly) == .content(week7, pendingReview: false))
        #expect(library.display(forWeek: 8, visibility: .reviewedOnly) == .underReview(week: 8))
        #expect(library.display(forWeek: 8, visibility: .all) == .content(week8, pendingReview: true))
        #expect(library.display(forWeek: 7, visibility: .all) == .content(week7, pendingReview: false))
    }

    @Test func upcomingMilestonesIncludeOnesUnderway() throws {
        let library = try library()
        #expect(library.upcomingMilestones(atWeek: 7).map(\.id) == ["m-early", "m-late"])
        #expect(library.upcomingMilestones(atWeek: 8).map(\.id) == ["m-early", "m-late"])
        #expect(library.upcomingMilestones(atWeek: 9).map(\.id) == ["m-late"])
        #expect(library.upcomingMilestones(atWeek: 15).isEmpty)
        #expect(library.upcomingMilestones(atWeek: 7, visibility: .reviewedOnly).map(\.id) == ["m-early"])
    }

    @Test func milestonesAreSortedByWeek() throws {
        var content = try fixtureContent()
        content.milestones.reverse()
        #expect(WeeklyContentLibrary(document: content).milestones.map(\.id) == ["m-early", "m-late"])
    }

    @Test func localizedAccessorsPickTheLanguage() throws {
        let library = try library()
        let week8 = try #require(library.content(forWeek: 8))
        #expect(week8.size.name(.vi) == "một quả anh đào")
        #expect(week8.size.name(.en) == "a cherry")
        #expect(week8.baby.items(.en) == ["Baby fact 8a.", "Baby fact 8b."])
        #expect(week8.warnings.items(.vi) == ["Gọi bác sĩ về 8."])
        #expect(library.milestones[0].title.text(.vi) == "Khám sớm")
    }

    @Test func contentLanguageFollowsTheFirstSupportedPreference() {
        #expect(ContentLanguage(preferredLanguages: ["vi-VN"]) == .vi)
        #expect(ContentLanguage(preferredLanguages: ["vi"]) == .vi)
        #expect(ContentLanguage(preferredLanguages: ["en-GB"]) == .en)
        #expect(ContentLanguage(preferredLanguages: ["fr-FR", "vi-VN"]) == .vi)
        #expect(ContentLanguage(preferredLanguages: ["fr-FR"]) == .en)
        #expect(ContentLanguage(preferredLanguages: []) == .en)
    }
}
