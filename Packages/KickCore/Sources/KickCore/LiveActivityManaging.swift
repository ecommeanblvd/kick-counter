import Foundation

/// Seam over ActivityKit. The real implementation lives in the app target
/// (ActivityKit and the activity attributes are iOS-only).
@MainActor
public protocol LiveActivityManaging: AnyObject {
    /// False when the user has turned Live Activities off in Settings.
    var isAvailable: Bool { get }
    func hasActivity(for sessionID: UUID) -> Bool
    /// Starts an activity for the session, ending activities of any other session.
    func start(sessionID: UUID, startedAt: Date, count: Int) async
    /// No-op when that session has no activity.
    func update(sessionID: UUID, count: Int, completedAt: Date?) async
    /// No-op when that session has no activity. `dismissAfter <= 0` removes it immediately.
    func end(sessionID: UUID, dismissAfter: TimeInterval) async
    func endAll() async
}
