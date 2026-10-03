import Foundation
import Testing
@testable import KickCore

/// Rules every shipped `pregnancy-content.json` must meet (see plan Task 5).
struct BundledContentTests {
    static let requiredMilestones: [String: ClosedRange<Int>] = [
        "confirm-pregnancy": 6...8,
        "nt-scan": 11...14,
        "triple-test": 15...18,
        "anomaly-scan": 18...22,
        "gdm-screening": 24...28,
        "tetanus-pertussis": 27...36,
        "growth-scan": 30...32,
        "gbs-test": 35...37,
        "weekly-checks": 37...40,
        "post-dates": 40...42,
    ]
    static let careWordsEN = ["doctor", "midwife", "maternity", "hospital", "emergency"]
    static let careWordsVI = ["bác sĩ", "cơ sở y tế", "bệnh viện", "cấp cứu", "115"]
    static let typicalMeasurements: [Int: (length: ClosedRange<Double>, weight: ClosedRange<Double>)] = [
        12: (4.5...7, 10...25),
        20: (15...27, 250...350),
        24: (28...33, 500...700),
        28: (35...39, 900...1200),
        40: (48...54, 3100...3700),
    ]

    let library: WeeklyContentLibrary

    init() throws {
        library = try WeeklyContentLibrary.bundled()
    }

    @Test func bundledContentPassesValidation() {
        let issues = ContentValidator.validate(library.document)
        #expect(issues.isEmpty, "\(issues)")
    }

    @Test func coversEveryWeekFrom4To42() {
        #expect(library.document.weeks.map(\.week) == Array(4...42))
    }

    @Test func lookupClampsToTheContentRange() {
        #expect(library.content(forWeek: 1)?.week == 4)
        #expect(library.content(forWeek: 24)?.week == 24)
        #expect(library.content(forWeek: 44)?.week == 42)
    }

    @Test func milestonesMatchTheSpecSchedule() {
        let actual = Dictionary(library.milestones.map { ($0.id, $0.fromWeek...$0.toWeek) }, uniquingKeysWith: { first, _ in first })
        #expect(actual == Self.requiredMilestones)
        #expect(library.milestones.count == Self.requiredMilestones.count)
    }

    @Test func everyWarningPointsToCare() {
        for week in library.document.weeks {
            for item in week.warnings.en {
                #expect(Self.careWordsEN.contains { item.localizedCaseInsensitiveContains($0) }, "week \(week.week): \(item)")
            }
            for item in week.warnings.vi {
                #expect(Self.careWordsVI.contains { item.localizedCaseInsensitiveContains($0) }, "week \(week.week): \(item)")
            }
        }
    }

    /// Core danger signs must be repeated every week of their stage, not only in some weeks.
    @Test func coreDangerSignsAppearEveryWeekOfTheirStage() {
        func mentions(_ items: [String], _ keywords: [String]) -> Bool {
            items.contains { item in keywords.contains { item.localizedCaseInsensitiveContains($0) } }
        }
        for week in library.document.weeks {
            let en = week.warnings.en
            let vi = week.warnings.vi
            #expect(mentions(en, ["fever"]), "week \(week.week): fever")
            #expect(mentions(vi, ["sốt"]), "week \(week.week): sốt")
            if week.week >= 20 {
                #expect(mentions(en, ["bleeding"]), "week \(week.week): bleeding")
                #expect(mentions(vi, ["ra máu"]), "week \(week.week): ra máu")
                #expect(mentions(en, ["headache"]), "week \(week.week): headache")
                #expect(mentions(en, ["vision"]), "week \(week.week): vision")
                #expect(mentions(en, ["fluid", "waters"]), "week \(week.week): leaking fluid")
            }
            if week.week >= 24 {
                #expect(mentions(en, ["mov"]), "week \(week.week): movements")
            }
        }
        let week24 = library.content(forWeek: 24)?.warnings.en ?? []
        #expect(mentions(week24, ["not felt your baby move"]), "week 24: not felt your baby move")
    }

    @Test func vietnameseTextHasDiacritics() {
        var texts: [String] = []
        for week in library.document.weeks {
            texts.append(week.size.vi)
            texts += week.baby.vi + week.mom.vi + week.tips.vi + week.warnings.vi
        }
        for milestone in library.milestones {
            texts += [milestone.title.vi, milestone.detail.vi]
        }
        let unaccented = texts.filter { !$0.unicodeScalars.contains { $0.value > 127 } }
        #expect(unaccented.isEmpty, "\(unaccented)")
    }

    @Test func sizeComparisonsAreDistinct() {
        let names = library.document.weeks.map(\.size.en)
        #expect(Set(names).count == names.count)
    }

    @Test func measurementsAreInTypicalRanges() {
        for (week, expected) in Self.typicalMeasurements {
            let content = library.content(forWeek: week)
            #expect(content?.lengthCm.map(expected.length.contains) == true, "week \(week) length")
            #expect(content?.weightG.map(expected.weight.contains) == true, "week \(week) weight")
        }
    }

    @Test func sourcesNameTheFourGuidelineBodies() {
        let joined = library.sources.joined(separator: " | ")
        for body in ["WHO", "ACOG", "NHS", "Bộ Y tế"] {
            #expect(joined.contains(body), "missing source: \(body)")
        }
    }
}
