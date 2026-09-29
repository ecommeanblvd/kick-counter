import Foundation

public enum AppGroup {
    public static let identifier = "group.com.lmtiep.kickcounter"

    public static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

/// Keys for preferences stored in `AppGroup.defaults` (read via @AppStorage).
public enum SettingsKey {
    public static let reminderEnabled = "reminderEnabled"
    public static let reminderHour = "reminderHour"
    public static let reminderMinute = "reminderMinute"
    /// `timeIntervalSince1970`; 0 means "not set".
    public static let dueDate = "dueDate"
    public static let hasCompletedOnboarding = "hasCompletedOnboarding"
}

public enum SettingsDefault {
    public static let reminderHour = 20
    public static let reminderMinute = 0
}
