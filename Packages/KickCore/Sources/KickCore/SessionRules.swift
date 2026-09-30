import Foundation

/// Rules of the "count to 10" (Cardiff) method.
public enum SessionRules {
    public static let targetCount = 10
    public static let overdueThreshold: TimeInterval = 2 * 60 * 60
    /// Taps closer together than this are treated as an accidental double tap.
    public static let debounceInterval: TimeInterval = 0.5
    /// An active session this old is treated as abandoned and auto-cancelled.
    public static let abandonAfter: TimeInterval = 12 * 60 * 60
    /// Never start or re-create a Live Activity for an active session this old.
    public static let liveActivityMaxAge: TimeInterval = 8 * 60 * 60
}
