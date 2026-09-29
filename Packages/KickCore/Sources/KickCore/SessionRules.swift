import Foundation

/// Rules of the "count to 10" (Cardiff) method.
public enum SessionRules {
    public static let targetCount = 10
    public static let overdueThreshold: TimeInterval = 2 * 60 * 60
    /// Taps closer together than this are treated as an accidental double tap.
    public static let debounceInterval: TimeInterval = 0.5
}
