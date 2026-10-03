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
    @AppStorage(SettingsKey.lmpDate, store: AppGroup.defaults) private var lmpDate: Double = 0
    @AppStorage(SettingsKey.pregnancyDateSource, store: AppGroup.defaults)
    private var pregnancyDateSource = PregnancyDateSource.dueDate.rawValue

    @State private var notificationsAuthorized = true
    @State private var showingPregnancyDates = false
    @State private var confirmingClearPregnancy = false

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
                    Button {
                        showingPregnancyDates = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            LabeledContent(dueDate > 0 ? L10n.settingsDueDate : L10n.settingsPregnancySet, value: dueDateText)
                            if let lmpText {
                                Text(L10n.settingsPregnancyFromLMP(lmpText))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tint(.primary)
                    .accessibilityIdentifier("settingsPregnancyDates")

                    if dueDate > 0 {
                        Button(L10n.settingsPregnancyClear, role: .destructive) {
                            confirmingClearPregnancy = true
                        }
                        .accessibilityIdentifier("settingsPregnancyClear")
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
                        .accessibilityIdentifier("settingsMedicalInfo")
                    LabeledContent(L10n.settingsVersion, value: appVersion)
                }
            }
            .navigationTitle(L10n.settingsTitle)
            .sheet(isPresented: $showingPregnancyDates) { PregnancyDateSheet() }
            .confirmationDialog(
                L10n.settingsPregnancyClearConfirm,
                isPresented: $confirmingClearPregnancy,
                titleVisibility: .visible
            ) {
                Button(L10n.settingsPregnancyClear, role: .destructive) { PregnancyProfile.clear(AppGroup.defaults) }
                Button(L10n.commonCancel, role: .cancel) {}
            }
            .task { await refreshPermissions() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refreshPermissions() } }
            }
            .onChange(of: reminderEnabled) { Task { await applyReminder() } }
            .onChange(of: reminderHour) { Task { await applyReminder() } }
            .onChange(of: reminderMinute) { Task { await applyReminder() } }
        }
    }

    private var dueDateText: String {
        guard dueDate > 0 else { return L10n.settingsPregnancyNotSet }
        return Date(timeIntervalSince1970: dueDate).formatted(date: .long, time: .omitted)
    }

    private var lmpText: String? {
        guard pregnancyDateSource == PregnancyDateSource.lmp.rawValue, lmpDate > 0 else { return nil }
        return Date(timeIntervalSince1970: lmpDate).formatted(date: .long, time: .omitted)
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
