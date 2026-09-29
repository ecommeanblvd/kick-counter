import Foundation
import KickCore
import KickData
import SwiftData

@MainActor
struct AppEnvironment {
    let container: ModelContainer
    let coordinator: KickCoordinator

    private static let arguments = ProcessInfo.processInfo.arguments
    static let isUITesting = arguments.contains("-uiTesting")
    static let forceDarkMode = arguments.contains("-forceDarkMode")

    static func make() throws -> AppEnvironment {
        if isUITesting {
            AppGroup.defaults.removePersistentDomain(forName: AppGroup.identifier)
            if arguments.contains("-skipOnboarding") {
                AppGroup.defaults.set(true, forKey: SettingsKey.hasCompletedOnboarding)
            }
        }
        let container = try KickPersistence.makeContainer(inMemory: isUITesting)
        let notificationCenter: NotificationCenterClient = isUITesting ? DisabledNotificationCenter() : SystemNotificationCenter()
        let liveActivities: LiveActivityManaging = NoopLiveActivityManager() // replaced in Task 11
        let coordinator = KickCoordinator(
            store: KickStore(context: container.mainContext),
            notifications: NotificationScheduler(center: notificationCenter),
            liveActivities: liveActivities,
            overdueText: NotificationText(title: L10n.overdueTitle, body: L10n.overdueBody)
        )
        return AppEnvironment(container: container, coordinator: coordinator)
    }
}
