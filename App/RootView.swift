import KickCore
import SwiftUI

enum AppTab: Hashable {
    case pregnancy
    case counter
    case history
    case settings
}

struct RootView: View {
    @Environment(KickCoordinator.self) private var coordinator
    @Environment(AppointmentCoordinator.self) private var appointments
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKey.hasCompletedOnboarding, store: AppGroup.defaults)
    private var hasCompletedOnboarding = false
    @State private var selectedTab: AppTab = .pregnancy

    var body: some View {
        TabView(selection: $selectedTab) {
            PregnancyHomeView { selectedTab = .counter }
                .tabItem { Label(L10n.tabPregnancy, systemImage: "heart.text.square.fill") }
                .tag(AppTab.pregnancy)
            CounterView()
                .tabItem { Label(L10n.tabCounter, systemImage: "hand.tap.fill") }
                .tag(AppTab.counter)
            HistoryView()
                .tabItem { Label(L10n.tabHistory, systemImage: "chart.bar.fill") }
                .tag(AppTab.history)
            SettingsView()
                .tabItem { Label(L10n.tabSettings, systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasCompletedOnboarding },
            set: { hasCompletedOnboarding = !$0 }
        )) {
            OnboardingView { hasCompletedOnboarding = true }
        }
        .task { await reload() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await reload() } }
        }
    }

    private func reload() async {
        await coordinator.load()
        await appointments.load()
    }
}
