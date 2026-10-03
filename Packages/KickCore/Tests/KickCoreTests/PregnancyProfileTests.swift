import Foundation
import Testing
@testable import KickCore

struct PregnancyProfileTests {
    /// A fresh, empty defaults domain per test.
    private func makeDefaults() -> UserDefaults {
        let name = "PregnancyProfileTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func emptyDefaultsHaveNoDates() {
        #expect(PregnancyProfile.load(from: makeDefaults()) == PregnancyProfile(source: .dueDate, dueDate: nil, lmpDate: nil))
    }

    @Test func version1DueDateKeepsWorkingWithoutMigration() {
        let defaults = makeDefaults()
        defaults.set(date("2027-01-19T12:00:00Z").timeIntervalSince1970, forKey: SettingsKey.dueDate)
        #expect(PregnancyProfile.load(from: defaults) == PregnancyProfile(source: .dueDate, dueDate: date("2027-01-19T12:00:00Z"), lmpDate: nil))
    }

    @Test func savingLMPStoresItAndTheDerivedDueDate() {
        let defaults = makeDefaults()
        PregnancyProfile.saveLMP(date("2026-07-01T12:00:00Z"), to: defaults, calendar: utcCalendar)
        #expect(PregnancyProfile.load(from: defaults) == PregnancyProfile(
            source: .lmp, dueDate: date("2027-04-07T12:00:00Z"), lmpDate: date("2026-07-01T12:00:00Z")
        ))
        #expect(defaults.double(forKey: SettingsKey.dueDate) == date("2027-04-07T12:00:00Z").timeIntervalSince1970)
    }

    @Test func savingDueDateClearsLMP() {
        let defaults = makeDefaults()
        PregnancyProfile.saveLMP(date("2026-07-01T12:00:00Z"), to: defaults, calendar: utcCalendar)
        PregnancyProfile.saveDueDate(date("2027-02-01T12:00:00Z"), to: defaults)
        #expect(PregnancyProfile.load(from: defaults) == PregnancyProfile(source: .dueDate, dueDate: date("2027-02-01T12:00:00Z"), lmpDate: nil))
        #expect(defaults.double(forKey: SettingsKey.lmpDate) == 0)
    }

    @Test func saveDispatchesOnSource() {
        let defaults = makeDefaults()
        PregnancyProfile.save(source: .lmp, date: date("2026-07-01T12:00:00Z"), to: defaults, calendar: utcCalendar)
        #expect(PregnancyProfile.load(from: defaults).source == .lmp)
        PregnancyProfile.save(source: .dueDate, date: date("2027-02-01T12:00:00Z"), to: defaults, calendar: utcCalendar)
        #expect(PregnancyProfile.load(from: defaults) == PregnancyProfile(source: .dueDate, dueDate: date("2027-02-01T12:00:00Z"), lmpDate: nil))
    }

    @Test func clearRemovesEverything() {
        let defaults = makeDefaults()
        PregnancyProfile.saveLMP(date("2026-07-01T12:00:00Z"), to: defaults, calendar: utcCalendar)
        PregnancyProfile.clear(defaults)
        #expect(PregnancyProfile.load(from: defaults) == PregnancyProfile(source: .dueDate, dueDate: nil, lmpDate: nil))
        #expect(defaults.double(forKey: SettingsKey.dueDate) == 0)
    }

    @Test func lmpSourceWithoutLMPDateFallsBackToDueDate() {
        let defaults = makeDefaults()
        defaults.set("lmp", forKey: SettingsKey.pregnancyDateSource)
        defaults.set(date("2027-01-19T12:00:00Z").timeIntervalSince1970, forKey: SettingsKey.dueDate)
        #expect(PregnancyProfile.load(from: defaults).source == .dueDate)
    }
}
