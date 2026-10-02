import Foundation

public enum ContentIssue: Equatable, Sendable {
    case unsupportedVersion(Int)
    case noSources
    case missingWeek(Int)
    case unexpectedWeek(Int)
    case duplicateWeek(Int)
    case weeksOutOfOrder
    /// `context` names the field, e.g. "week 7 baby.en" or "milestone nt-scan title.vi".
    case blankText(String)
    case tooFewItems(week: Int, section: String, language: ContentLanguage, minimum: Int)
    case translationCountMismatch(week: Int, section: String)
    case missingMeasurement(week: Int, field: String)
    case nonPositiveMeasurement(week: Int, field: String)
    case decreasingMeasurement(week: Int, field: String)
    case invalidMilestoneRange(id: String)
    case duplicateMilestoneID(String)
}

/// Structural rules for `pregnancy-content.json`, enforced by unit tests so a
/// broken file never ships (the app itself only logs and hides content).
public enum ContentValidator {
    public static let supportedVersion = 1
    public static let measurementsRequiredFromWeek = 8
    static let minimumItems: [(section: String, minimum: Int)] = [
        ("baby", 2), ("mom", 2), ("tips", 2), ("warnings", 1),
    ]

    public static func validate(
        _ content: PregnancyContent,
        requiredWeeks: ClosedRange<Int> = WeeklyContentLibrary.weekRange
    ) -> [ContentIssue] {
        var issues: [ContentIssue] = []
        if content.version != supportedVersion { issues.append(.unsupportedVersion(content.version)) }
        if content.sources.isEmpty { issues.append(.noSources) }
        for source in content.sources where isBlank(source) { issues.append(.blankText("sources")) }
        issues += weekIssues(content.weeks, requiredWeeks: requiredWeeks)
        issues += measurementIssues(content.weeks.sorted { $0.week < $1.week })
        issues += milestoneIssues(content.milestones)
        return issues
    }

    private static func weekIssues(_ weeks: [WeekContent], requiredWeeks: ClosedRange<Int>) -> [ContentIssue] {
        var issues: [ContentIssue] = []
        var seen = Set<Int>()
        for week in weeks {
            if !seen.insert(week.week).inserted { issues.append(.duplicateWeek(week.week)) }
            if !requiredWeeks.contains(week.week) { issues.append(.unexpectedWeek(week.week)) }
        }
        for number in requiredWeeks where !seen.contains(number) { issues.append(.missingWeek(number)) }
        let numbers = weeks.map(\.week)
        if numbers != numbers.sorted() { issues.append(.weeksOutOfOrder) }

        for week in weeks {
            let number = week.week
            let sizeFields = [("size.emoji", week.size.emoji), ("size.en", week.size.en), ("size.vi", week.size.vi)]
            for (field, text) in sizeFields where isBlank(text) {
                issues.append(.blankText("week \(number) \(field)"))
            }
            let sections = ["baby": week.baby, "mom": week.mom, "tips": week.tips, "warnings": week.warnings]
            for (section, minimum) in minimumItems {
                guard let list = sections[section] else { continue }
                for language in ContentLanguage.allCases {
                    let items = list.items(language)
                    if items.count < minimum {
                        issues.append(.tooFewItems(week: number, section: section, language: language, minimum: minimum))
                    }
                    if items.contains(where: isBlank) {
                        issues.append(.blankText("week \(number) \(section).\(language.rawValue)"))
                    }
                }
                if list.en.count != list.vi.count {
                    issues.append(.translationCountMismatch(week: number, section: section))
                }
            }
        }
        return issues
    }

    private static func measurementIssues(_ weeks: [WeekContent]) -> [ContentIssue] {
        var issues: [ContentIssue] = []
        let fields: [(name: String, value: (WeekContent) -> Double?)] = [
            ("lengthCm", { $0.lengthCm }), ("weightG", { $0.weightG }),
        ]
        for field in fields {
            var previous: Double?
            for week in weeks {
                guard let value = field.value(week) else {
                    if week.week >= measurementsRequiredFromWeek {
                        issues.append(.missingMeasurement(week: week.week, field: field.name))
                    }
                    continue
                }
                if value <= 0 { issues.append(.nonPositiveMeasurement(week: week.week, field: field.name)) }
                if let previous, value < previous {
                    issues.append(.decreasingMeasurement(week: week.week, field: field.name))
                }
                previous = value
            }
        }
        return issues
    }

    private static func milestoneIssues(_ milestones: [Milestone]) -> [ContentIssue] {
        var issues: [ContentIssue] = []
        var ids = Set<String>()
        let allowed = WeeklyContentLibrary.weekRange
        for milestone in milestones {
            if isBlank(milestone.id) { issues.append(.blankText("milestone id")) }
            if !ids.insert(milestone.id).inserted { issues.append(.duplicateMilestoneID(milestone.id)) }
            if milestone.fromWeek > milestone.toWeek
                || !allowed.contains(milestone.fromWeek)
                || !allowed.contains(milestone.toWeek) {
                issues.append(.invalidMilestoneRange(id: milestone.id))
            }
            for language in ContentLanguage.allCases {
                if isBlank(milestone.title.text(language)) {
                    issues.append(.blankText("milestone \(milestone.id) title.\(language.rawValue)"))
                }
                if isBlank(milestone.detail.text(language)) {
                    issues.append(.blankText("milestone \(milestone.id) detail.\(language.rawValue)"))
                }
            }
        }
        return issues
    }

    static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
