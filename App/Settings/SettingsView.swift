import KickCore
import SwiftUI

struct SettingsView: View {
    @Environment(KickCoordinator.self) private var coordinator
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(SettingsKey.reminderEnabled, store: AppGroup.defaults) private var reminderEnabled = false
    @AppStorage(SettingsKey.reminderHour, store: AppGroup.defaults) private var reminderHour = SettingsDefault.reminderHour
    @AppStorage(SettingsKey.reminderMinute, store: AppGroup.defaults) private var reminderMinute = SettingsDefault.reminderMinute
    @AppStorage(SettingsKey.dueDate, store: AppGroup.defaults) private var dueDate: Double = 0

    @State private var notificationsAuthorized = true

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.settingsReminderSection) {
                    Toggle(L10n.settingsReminderToggle, isOn: $reminderEnabled)
                        .accessibilityIdentifier("settingsReminderToggle")
                    if reminderEnabled {
                        DatePicker(L10n.settingsReminderTime, selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                }

                Section(L10n.settingsPregnancySection) {
                    Toggle(L10n.settingsDueDateToggle, isOn: hasDueDate)
                        .accessibilityIdentifier("settingsDueDateToggle")
                    if dueDate > 0 {
                        DatePicker(
                            L10n.settingsDueDate,
                            selection: dueDateValue,
                            in: Date.now...Date.now.addingTimeInterval(300 * 86_400),
                            displayedComponents: .date
                        )
                    }
                }

                if !notificationsAuthorized || !coordinator.liveActivitiesAvailable {
                    Section(L10n.settingsPermissionsSection) {
                        if !notificationsAuthorized {
                            Text(L10n.settingsNotificationsDenied).font(.footnote)
                        }
                        if !coordinator.liveActivitiesAvailable {
                            Text(L10n.settingsLiveActivitiesOff).font(.footnote)
                        }
                        Button(L10n.settingsOpenSettings) {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                }

                Section(L10n.settingsAboutSection) {
                    NavigationLink(L10n.settingsMedicalInfo) { MedicalInfoView() }
                    LabeledContent(L10n.settingsVersion, value: appVersion)
                }
            }
            .navigationTitle(L10n.settingsTitle)
            .task { await refreshPermissions() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refreshPermissions() } }
            }
            .onChange(of: reminderEnabled) { Task { await applyReminder() } }
            .onChange(of: reminderHour) { Task { await applyReminder() } }
            .onChange(of: reminderMinute) { Task { await applyReminder() } }
        }
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: reminderHour, minute: reminderMinute)) ?? .now
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                reminderHour = components.hour ?? SettingsDefault.reminderHour
                reminderMinute = components.minute ?? SettingsDefault.reminderMinute
            }
        )
    }

    private var hasDueDate: Binding<Bool> {
        Binding(
            get: { dueDate > 0 },
            set: { enabled in
                dueDate = enabled ? Date.now.addingTimeInterval(90 * 86_400).timeIntervalSince1970 : 0
            }
        )
    }

    private var dueDateValue: Binding<Date> {
        Binding(
            get: { Date(timeIntervalSince1970: dueDate) },
            set: { dueDate = $0.timeIntervalSince1970 }
        )
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private func applyReminder() async {
        let scheduled = await coordinator.setDailyReminder(
            enabled: reminderEnabled,
            hour: reminderHour,
            minute: reminderMinute,
            text: NotificationText(title: L10n.reminderTitle, body: L10n.reminderBody)
        )
        if !scheduled {
            reminderEnabled = false
        }
        await refreshPermissions()
    }

    private func refreshPermissions() async {
        notificationsAuthorized = await coordinator.notificationsAuthorized()
    }
}
