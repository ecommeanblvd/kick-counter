import Foundation
import KickCore
import KickData
import SwiftData

@MainActor
struct AppEnvironment {
    let container: ModelContainer
    let coordinator: KickCoordinator
    let appointments: AppointmentCoordinator
    let content: WeeklyContentLibrary?

    private static let arguments = ProcessInfo.processInfo.arguments
    #if DEBUG
    static let isUITesting = AppClock.launchOptions.isUITesting
    static let forceDarkMode = arguments.contains("-forceDarkMode")
    #else
    static let isUITesting = false
    static let forceDarkMode = false
    #endif

    static func make() throws -> AppEnvironment {
        #if DEBUG
        if isUITesting {
            AppGroup.defaults.removePersistentDomain(forName: AppGroup.identifier)
            if arguments.contains("-skipOnboarding") {
                AppGroup.defaults.set(true, forKey: SettingsKey.hasCompletedOnboarding)
            }
            if let seededDueDate = AppClock.launchOptions.seedDueDate {
                PregnancyProfile.saveDueDate(seededDueDate, to: AppGroup.defaults)
            }
        }
        #endif
        let container = try KickPersistence.makeContainer(inMemory: isUITesting)
        let notificationCenter: NotificationCenterClient = isUITesting ? DisabledNotificationCenter() : SystemNotificationCenter()
        let liveActivities: LiveActivityManaging = isUITesting ? NoopLiveActivityManager() : SystemLiveActivityManager()
        let notifications = NotificationScheduler(center: notificationCenter)
        let coordinator = KickCoordinator(
            store: KickStore(context: container.mainContext),
            notifications: notifications,
            liveActivities: liveActivities,
            overdueText: NotificationText(title: L10n.overdueTitle, body: L10n.overdueBody)
        )
        let appointments = AppointmentCoordinator(
            store: AppointmentStore(context: container.mainContext),
            notifications: notifications,
            reminderText: NotificationText(title: L10n.appointmentsReminderTitle, body: L10n.appointmentsReminderBody),
            now: { AppClock.now() }
        )
        return AppEnvironment(
            container: container,
            coordinator: coordinator,
            appointments: appointments,
            content: WeeklyContentLibrary.loadBundled()
        )
    }
}
