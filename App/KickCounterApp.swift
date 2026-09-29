import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "app")

@main
struct KickCounterApp: App {
    private let environment: Result<AppEnvironment, Error>

    init() {
        environment = Result { try AppEnvironment.make() }
        if case .failure(let error) = environment {
            logger.fault("Could not open the data store: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            switch environment {
            case .success(let env):
                RootView()
                    .environment(env.coordinator)
                    .modelContainer(env.container)
                    .preferredColorScheme(AppEnvironment.forceDarkMode ? .dark : nil)
            case .failure:
                StoreErrorView()
            }
        }
    }
}
