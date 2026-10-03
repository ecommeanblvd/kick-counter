import Foundation
import KickCore

/// Typed access to Localizable.xcstrings. Every user-facing string goes through here.
enum L10n {
    private static func t(_ key: String.LocalizationValue) -> String { String(localized: key) }

    static var tabCounter: String { t("tab.counter") }
    static var tabHistory: String { t("tab.history") }
    static var tabSettings: String { t("tab.settings") }
    static var tabPregnancy: String { t("tab.pregnancy") }

    static var pregnancyTitle: String { t("pregnancy.title") }
    static var pregnancyEmptyTitle: String { t("pregnancy.empty.title") }
    static var pregnancyEmptyBody: String { t("pregnancy.empty.body") }
    static var pregnancyEmptyAction: String { t("pregnancy.empty.action") }
    static var pregnancyInvalidTitle: String { t("pregnancy.invalid.title") }
    static var pregnancyInvalidBody: String { t("pregnancy.invalid.body") }
    static var pregnancyEditDate: String { t("pregnancy.editDate") }
    static func pregnancyTrimester(_ number: Int) -> String { String(format: t("pregnancy.trimester"), number) }
    static func pregnancyDaysLeft(_ days: Int) -> String { String(format: t("pregnancy.daysLeft"), days) }
    static var pregnancyDueToday: String { t("pregnancy.dueToday") }
    static func pregnancyPastDueTitle(_ days: Int) -> String { String(format: t("pregnancy.pastDue.title"), days) }
    static var pregnancyPastDueBody: String { t("pregnancy.pastDue.body") }
    static func pregnancyBabySize(_ name: String) -> String { String(format: t("pregnancy.baby.size"), name) }
    static var pregnancyBabyLength: String { t("pregnancy.baby.length") }
    static var pregnancyBabyWeight: String { t("pregnancy.baby.weight") }
    static var pregnancyTipsTitle: String { t("pregnancy.tips.title") }
    static var pregnancySeeWeek: String { t("pregnancy.seeWeek") }
    static var pregnancyAppointmentTitle: String { t("pregnancy.appointment.title") }
    static var pregnancyAppointmentNone: String { t("pregnancy.appointment.none") }
    static func pregnancyAppointmentSuggested(_ from: Int, _ to: Int) -> String {
        String(format: t("pregnancy.appointment.suggested"), from, to)
    }
    static var pregnancyKickCardTitle: String { t("pregnancy.kickCard.title") }
    static var pregnancyKickCardBody: String { t("pregnancy.kickCard.body") }

    static func weekTitle(_ week: Int) -> String { String(format: t("week.title"), week) }
    static var weekCurrent: String { t("week.current") }
    static var weekBaby: String { t("week.baby") }
    static var weekMom: String { t("week.mom") }
    static var weekTips: String { t("week.tips") }
    static var weekWarnings: String { t("week.warnings") }
    static var weekUnderReview: String { t("week.underReview") }
    static var weekPendingReview: String { t("week.pendingReview") }

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
    static var commonSave: String { t("common.save") }

    static var settingsTitle: String { t("settings.title") }
    static var settingsReminderSection: String { t("settings.reminder.section") }
    static var settingsReminderToggle: String { t("settings.reminder.toggle") }
    static var settingsReminderTime: String { t("settings.reminder.time") }
    static var settingsPregnancySection: String { t("settings.pregnancy.section") }
    static var settingsDueDate: String { t("settings.dueDate") }
    static var settingsPermissionsSection: String { t("settings.permissions.section") }
    static var settingsNotificationsDenied: String { t("settings.notifications.denied") }
    static var settingsLiveActivitiesOff: String { t("settings.liveActivities.off") }
    static var settingsOpenSettings: String { t("settings.openSettings") }
    static var settingsAboutSection: String { t("settings.about.section") }
    static var settingsMedicalInfo: String { t("settings.medicalInfo") }
    static var settingsVersion: String { t("settings.version") }
    static var settingsPregnancySet: String { t("settings.pregnancy.set") }
    static var settingsPregnancyNotSet: String { t("settings.pregnancy.notSet") }
    static func settingsPregnancyFromLMP(_ date: String) -> String { String(format: t("settings.pregnancy.fromLMP"), date) }
    static var settingsPregnancyClear: String { t("settings.pregnancy.clear") }
    static var settingsPregnancyClearConfirm: String { t("settings.pregnancy.clear.confirm") }

    static var pregnancyDateTitle: String { t("pregnancyDate.title") }
    static var pregnancyDateSourceLabel: String { t("pregnancyDate.source") }
    static var pregnancyDateSourceDueDate: String { t("pregnancyDate.source.dueDate") }
    static var pregnancyDateSourceLMP: String { t("pregnancyDate.source.lmp") }
    static var pregnancyDateLMPLabel: String { t("pregnancyDate.lmp") }
    static var pregnancyDateHintDueDate: String { t("pregnancyDate.hint.dueDate") }
    static var pregnancyDateHintLMP: String { t("pregnancyDate.hint.lmp") }
    static func pregnancyDateEstimatedDue(_ date: String) -> String { String(format: t("pregnancyDate.estimatedDue"), date) }

    static var reminderTitle: String { t("reminder.title") }
    static var reminderBody: String { t("reminder.body") }

    static var appointmentsReminderTitle: String { t("appointments.reminder.title") }
    static var appointmentsReminderBody: String { t("appointments.reminder.body") }
    static var appointmentsTitle: String { t("appointments.title") }
    static var appointmentsUpcoming: String { t("appointments.upcoming") }
    static var appointmentsPast: String { t("appointments.past") }
    static var appointmentsEmpty: String { t("appointments.empty") }
    static var appointmentsAdd: String { t("appointments.add") }
    static var appointmentsEdit: String { t("appointments.edit") }
    static var appointmentsFieldTitle: String { t("appointments.field.title") }
    static var appointmentsFieldDate: String { t("appointments.field.date") }
    static var appointmentsFieldNote: String { t("appointments.field.note") }
    static var appointmentsMarkDone: String { t("appointments.markDone") }
    static var appointmentsStatusDone: String { t("appointments.status.done") }
    static var appointmentsMilestones: String { t("appointments.milestones") }
    static var appointmentsMilestoneAdd: String { t("appointments.milestone.add") }
    static var appointmentsNotificationsOff: String { t("appointments.notificationsOff") }
    static var appointmentsDeleteConfirmTitle: String { t("appointments.delete.confirm.title") }
    static func milestoneWeeks(_ from: Int, _ to: Int) -> String { String(format: t("milestone.weeks"), from, to) }

    static var medicalTitle: String { t("medical.title") }
    static var medicalBody: String { t("medical.body") }
    static var medicalSourcesTitle: String { t("medical.sources.title") }
    static var medicalSourcesNote: String { t("medical.sources.note") }

    static var onboarding1Title: String { t("onboarding.1.title") }
    static var onboarding1Body: String { t("onboarding.1.body") }
    static var onboarding2Title: String { t("onboarding.2.title") }
    static var onboarding2Body: String { t("onboarding.2.body") }
    static var onboarding3Title: String { t("onboarding.3.title") }
    static var onboarding3Body: String { t("onboarding.3.body") }
    static var onboardingNext: String { t("onboarding.next") }
    static var onboardingAgree: String { t("onboarding.agree") }
    static var onboarding4Title: String { t("onboarding.4.title") }
    static var onboarding4Body: String { t("onboarding.4.body") }
    static var onboardingLater: String { t("onboarding.later") }

    static var errorSave: String { t("error.save") }
    static var errorLoad: String { t("error.load") }
    static var errorStoreTitle: String { t("error.store.title") }
    static var errorStoreBody: String { t("error.store.body") }

    static var laOverdue: String { t("la.overdue") }
    static var laCompleted: String { t("la.completed") }
    static var laAdd: String { t("la.add") }
}
