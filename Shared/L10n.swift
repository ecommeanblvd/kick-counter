import Foundation
import KickCore

/// Typed access to Localizable.xcstrings. Every user-facing string goes through here.
enum L10n {
    private static func t(_ key: String.LocalizationValue) -> String { String(localized: key) }

    static var tabCounter: String { t("tab.counter") }
    static var tabHistory: String { t("tab.history") }
    static var tabSettings: String { t("tab.settings") }

    static var counterTitle: String { t("counter.title") }
    static var counterStart: String { t("counter.start") }
    static var counterTapHint: String { t("counter.tapHint") }
    static var counterElapsed: String { t("counter.elapsed") }
    static var counterUndo: String { t("counter.undo") }
    static var counterCancel: String { t("counter.cancel") }
    static var counterCancelConfirmTitle: String { t("counter.cancel.confirm.title") }
    static var counterCancelConfirmMessage: String { t("counter.cancel.confirm.message") }
    static var counterKeepCounting: String { t("counter.keepCounting") }
    static var counterA11yButton: String { t("counter.a11y.button") }
    static func counterA11yValue(_ count: Int, _ target: Int) -> String { String(format: t("counter.a11y.value"), count, target) }
    static func counterProgress(_ count: Int, _ target: Int) -> String { String(format: t("counter.progress"), count, target) }
    static func counterWeek(_ week: GestationalWeek) -> String { String(format: t("counter.week"), week.weeks, week.days) }

    static var overdueTitle: String { t("overdue.title") }
    static var overdueBody: String { t("overdue.body") }

    static var completionTitle: String { t("completion.title") }
    static func completionDuration(_ text: String) -> String { String(format: t("completion.duration"), text) }
    static var completionExceeded: String { t("completion.exceeded") }
    static var completionDone: String { t("completion.done") }

    static var historyTitle: String { t("history.title") }
    static var historyChartTitle: String { t("history.chart.title") }
    static var historyChartDay: String { t("history.chart.day") }
    static var historyChartMinutes: String { t("history.chart.minutes") }
    static var historyChartThreshold: String { t("history.chart.threshold") }
    static var historyEmptyTitle: String { t("history.empty.title") }
    static var historyEmptyBody: String { t("history.empty.body") }
    static var historyStatusCompleted: String { t("history.status.completed") }
    static var historyStatusCancelled: String { t("history.status.cancelled") }
    static func historyRowCount(_ count: Int) -> String { String(format: t("history.row.count"), count) }
    static var historyDeleteConfirmTitle: String { t("history.delete.confirm.title") }

    static var commonDelete: String { t("common.delete") }
    static var commonCancel: String { t("common.cancel") }
    static var commonOK: String { t("common.ok") }

    static var settingsTitle: String { t("settings.title") }
    static var settingsReminderSection: String { t("settings.reminder.section") }
    static var settingsReminderToggle: String { t("settings.reminder.toggle") }
    static var settingsReminderTime: String { t("settings.reminder.time") }
    static var settingsPregnancySection: String { t("settings.pregnancy.section") }
    static var settingsDueDateToggle: String { t("settings.dueDate.toggle") }
    static var settingsDueDate: String { t("settings.dueDate") }
    static var settingsPermissionsSection: String { t("settings.permissions.section") }
    static var settingsNotificationsDenied: String { t("settings.notifications.denied") }
    static var settingsLiveActivitiesOff: String { t("settings.liveActivities.off") }
    static var settingsOpenSettings: String { t("settings.openSettings") }
    static var settingsAboutSection: String { t("settings.about.section") }
    static var settingsMedicalInfo: String { t("settings.medicalInfo") }
    static var settingsVersion: String { t("settings.version") }

    static var reminderTitle: String { t("reminder.title") }
    static var reminderBody: String { t("reminder.body") }

    static var appointmentsReminderTitle: String { t("appointments.reminder.title") }
    static var appointmentsReminderBody: String { t("appointments.reminder.body") }

    static var medicalTitle: String { t("medical.title") }
    static var medicalBody: String { t("medical.body") }

    static var onboarding1Title: String { t("onboarding.1.title") }
    static var onboarding1Body: String { t("onboarding.1.body") }
    static var onboarding2Title: String { t("onboarding.2.title") }
    static var onboarding2Body: String { t("onboarding.2.body") }
    static var onboarding3Title: String { t("onboarding.3.title") }
    static var onboarding3Body: String { t("onboarding.3.body") }
    static var onboardingNext: String { t("onboarding.next") }
    static var onboardingAgree: String { t("onboarding.agree") }

    static var errorSave: String { t("error.save") }
    static var errorLoad: String { t("error.load") }
    static var errorStoreTitle: String { t("error.store.title") }
    static var errorStoreBody: String { t("error.store.body") }

    static var laOverdue: String { t("la.overdue") }
    static var laCompleted: String { t("la.completed") }
    static var laAdd: String { t("la.add") }
}
