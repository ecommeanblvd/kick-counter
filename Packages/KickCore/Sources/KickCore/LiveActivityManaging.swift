import Foundation

/// Seam over ActivityKit. The real implementation lives in the app target
/// (ActivityKit and the activity attributes are iOS-only).
@MainActor
public protocol LiveActivityManaging: AnyObject {
    /// False when the user has turned Live Activities off in Settings.
    var isAvailable: Bool { get }
    func hasActivity(for sessionID: UUID) -> Bool
    func start(sessionID: UUID, startedAt: Date, count: Int) async
    func update(count: Int, completedAt: Date?) async
    /// `dismissAfter <= 0` removes the activity immediately.
    func end(dismissAfter: TimeInterval) async
    func endAll() async
}
