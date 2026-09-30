import Foundation

public enum SessionStatus: String, Codable, Sendable {
    case active, completed, cancelled
}

/// Value snapshot of a counting session; the engine operates only on this.
public struct SessionState: Equatable, Sendable {
    public var startedAt: Date
    public var kicks: [Date]
    public var status: SessionStatus
    public var endedAt: Date?
    public var exceededThreshold: Bool

    public init(
        startedAt: Date,
        kicks: [Date] = [],
        status: SessionStatus = .active,
        endedAt: Date? = nil,
        exceededThreshold: Bool = false
    ) {
        self.startedAt = startedAt
        self.kicks = kicks
        self.status = status
        self.endedAt = endedAt
        self.exceededThreshold = exceededThreshold
    }

    public var count: Int { kicks.count }

    public var duration: TimeInterval? {
        endedAt.map { $0.timeIntervalSince(startedAt) }
    }
}

public enum KickOutcome: Equatable, Sendable {
    case added(count: Int)
    case completed(duration: TimeInterval)
    case ignoredDebounce
    case ignoredInactive
}

public enum SessionEngine {
    public static func addKick(to state: inout SessionState, at now: Date) -> KickOutcome {
        guard state.status == .active else { return .ignoredInactive }
        if let last = state.kicks.last, now.timeIntervalSince(last) < SessionRules.debounceInterval {
            return .ignoredDebounce
        }
        state.kicks.append(now)
        guard state.count >= SessionRules.targetCount else { return .added(count: state.count) }

        let duration = now.timeIntervalSince(state.startedAt)
        state.status = .completed
        state.endedAt = now
        state.exceededThreshold = duration >= SessionRules.overdueThreshold
        return .completed(duration: duration)
    }

    @discardableResult
    public static func undoLastKick(_ state: inout SessionState) -> Bool {
        guard state.status == .active, !state.kicks.isEmpty else { return false }
        state.kicks.removeLast()
        return true
    }

    public static func cancel(_ state: inout SessionState, at now: Date) {
        guard state.status == .active else { return }
        state.status = .cancelled
        state.endedAt = now
    }

    public static func isOverdue(_ state: SessionState, now: Date) -> Bool {
        state.status == .active && now.timeIntervalSince(state.startedAt) >= SessionRules.overdueThreshold
    }

    public static func isAbandoned(_ state: SessionState, now: Date) -> Bool {
        state.status == .active && now.timeIntervalSince(state.startedAt) >= SessionRules.abandonAfter
    }

    public static func elapsed(_ state: SessionState, now: Date) -> TimeInterval {
        max(0, (state.endedAt ?? now).timeIntervalSince(state.startedAt))
    }
}
