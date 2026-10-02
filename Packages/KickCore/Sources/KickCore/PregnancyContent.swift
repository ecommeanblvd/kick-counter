import Foundation

/// Language of the bundled medical content: the first of the user's preferred
/// languages that the content supports (the same rule the app's own
/// localization follows), falling back to English.
public enum ContentLanguage: String, Codable, Sendable, CaseIterable {
    case en
    case vi

    public init(preferredLanguages: [String]) {
        for identifier in preferredLanguages {
            switch Locale(identifier: identifier).language.languageCode?.identifier {
            case "vi":
                self = .vi
                return
            case "en":
                self = .en
                return
            default:
                continue
            }
        }
        self = .en
    }

    public static var current: ContentLanguage {
        ContentLanguage(preferredLanguages: Locale.preferredLanguages)
    }
}

public struct LocalizedText: Codable, Equatable, Sendable {
    public var en: String
    public var vi: String

    public func text(_ language: ContentLanguage) -> String {
        language == .vi ? vi : en
    }
}

public struct LocalizedList: Codable, Equatable, Sendable {
    public var en: [String]
    public var vi: [String]

    public func items(_ language: ContentLanguage) -> [String] {
        language == .vi ? vi : en
    }
}

/// "Your baby is about the size of …", illustrated by an emoji (no images).
public struct FruitSize: Codable, Equatable, Sendable {
    public var emoji: String
    public var en: String
    public var vi: String

    public func name(_ language: ContentLanguage) -> String {
        language == .vi ? vi : en
    }
}

public struct WeekContent: Codable, Equatable, Sendable, Identifiable {
    public var week: Int
    /// Set to true by the reviewing obstetrician; Release builds hide unreviewed weeks.
    public var reviewed: Bool
    public var size: FruitSize
    /// Absent before week 8 (shown as "—").
    public var lengthCm: Double?
    public var weightG: Double?
    public var baby: LocalizedList
    public var mom: LocalizedList
    public var tips: LocalizedList
    /// "When to get care right away" — every item points to a doctor or maternity unit.
    public var warnings: LocalizedList

    public var id: Int { week }
}

/// A suggested check-up, e.g. the nuchal translucency scan in weeks 11–14.
public struct Milestone: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var fromWeek: Int
    public var toWeek: Int
    public var title: LocalizedText
    public var detail: LocalizedText
    public var reviewed: Bool
}

/// Root of `pregnancy-content.json`.
public struct PregnancyContent: Codable, Equatable, Sendable {
    public var version: Int
    public var sources: [String]
    public var weeks: [WeekContent]
    public var milestones: [Milestone]
}
