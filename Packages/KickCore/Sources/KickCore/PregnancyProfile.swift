import Foundation

public enum PregnancyDateSource: String, Sendable, CaseIterable {
    case dueDate
    case lmp
}

/// The pregnancy dates kept in `AppGroup.defaults` (not synced). `SettingsKey.dueDate`
/// is the single source of truth; the LMP is kept only to show what the mother entered.
/// Clearing writes 0 rather than removing keys so `@AppStorage` views update.
public struct PregnancyProfile: Equatable, Sendable {
    public let source: PregnancyDateSource
    public let dueDate: Date?
    public let lmpDate: Date?

    public init(source: PregnancyDateSource, dueDate: Date?, lmpDate: Date?) {
        self.source = source
        self.dueDate = dueDate
        self.lmpDate = lmpDate
    }

    public static func load(from defaults: UserDefaults) -> PregnancyProfile {
        let due = defaults.double(forKey: SettingsKey.dueDate)
        let lmp = defaults.double(forKey: SettingsKey.lmpDate)
        let lmpDate = lmp > 0 ? Date(timeIntervalSince1970: lmp) : nil
        let stored = defaults.string(forKey: SettingsKey.pregnancyDateSource).flatMap(PregnancyDateSource.init(rawValue:))
        return PregnancyProfile(
            source: stored == .lmp && lmpDate != nil ? .lmp : .dueDate,
            dueDate: due > 0 ? Date(timeIntervalSince1970: due) : nil,
            lmpDate: lmpDate
        )
    }

    public static func saveDueDate(_ dueDate: Date, to defaults: UserDefaults) {
        defaults.set(dueDate.timeIntervalSince1970, forKey: SettingsKey.dueDate)
        defaults.set(0.0, forKey: SettingsKey.lmpDate)
        defaults.set(PregnancyDateSource.dueDate.rawValue, forKey: SettingsKey.pregnancyDateSource)
    }

    public static func saveLMP(_ lmp: Date, to defaults: UserDefaults, calendar: Calendar = .current) {
        let due = PregnancyDates.dueDate(fromLMP: lmp, calendar: calendar)
        defaults.set(due.timeIntervalSince1970, forKey: SettingsKey.dueDate)
        defaults.set(lmp.timeIntervalSince1970, forKey: SettingsKey.lmpDate)
        defaults.set(PregnancyDateSource.lmp.rawValue, forKey: SettingsKey.pregnancyDateSource)
    }

    public static func save(source: PregnancyDateSource, date: Date, to defaults: UserDefaults, calendar: Calendar = .current) {
        switch source {
        case .dueDate: saveDueDate(date, to: defaults)
        case .lmp: saveLMP(date, to: defaults, calendar: calendar)
        }
    }

    public static func clear(_ defaults: UserDefaults) {
        defaults.set(0.0, forKey: SettingsKey.dueDate)
        defaults.set(0.0, forKey: SettingsKey.lmpDate)
        defaults.set(PregnancyDateSource.dueDate.rawValue, forKey: SettingsKey.pregnancyDateSource)
    }
}
