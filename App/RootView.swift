import KickCore
import SwiftUI

struct RootView: View {
    @Environment(KickCoordinator.self) private var coordinator
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKey.hasCompletedOnboarding, store: AppGroup.defaults)
    private var hasCompletedOnboarding = false

    var body: some View {
        TabView {
            CounterView()
                .tabItem { Label(L10n.tabCounter, systemImage: "hand.tap.fill") }
            HistoryView()
                .tabItem { Label(L10n.tabHistory, systemImage: "chart.bar.fill") }
            Text(L10n.settingsTitle) // replaced by SettingsView in Task 10
                .tabItem { Label(L10n.tabSettings, systemImage: "gearshape.fill") }
        }
        .task { await coordinator.load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await coordinator.load() } }
        }
    }
}
