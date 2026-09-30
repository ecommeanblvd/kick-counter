import Foundation

public struct DailySummary: Equatable, Identifiable, Sendable {
    public let day: Date
    public let minutesToTarget: Double
    public let exceededThreshold: Bool
    public var id: Date { day }

    public init(day: Date, minutesToTarget: Double, exceededThreshold: Bool) {
        self.day = day
        self.minutesToTarget = minutesToTarget
        self.exceededThreshold = exceededThreshold
    }
}

public enum HistorySummary {
    public static let defaultDays = 14

    /// One bar per day for the last `days` days (today inclusive), using the
    /// most recently started completed session of each day.
    public static func daily(
        _ sessions: [SessionState],
        endingAt now: Date,
        days: Int = defaultDays,
        calendar: Calendar = .current
    ) -> [DailySummary] {
        let today = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }

        var latestPerDay: [Date: SessionState] = [:]
        for session in sessions where session.status == .completed && session.duration != nil {
            let day = calendar.startOfDay(for: session.startedAt)
            guard day >= windowStart, day <= today else { continue }
            if let current = latestPerDay[day], current.startedAt >= session.startedAt { continue }
            latestPerDay[day] = session
        }

        return latestPerDay
            .map { day, session in
                DailySummary(
                    day: day,
                    minutesToTarget: (session.duration ?? 0) / 60,
                    exceededThreshold: session.exceededThreshold
                )
            }
            .sorted { $0.day < $1.day }
    }
}
