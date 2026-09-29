import Charts
import KickCore
import SwiftUI

struct HistoryChart: View {
    let summaries: [DailySummary]
    let endingAt: Date

    private var domain: ClosedRange<Date> {
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endingAt))!
        let start = calendar.date(byAdding: .day, value: -HistorySummary.defaultDays, to: end)!
        return start...end
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.historyChartTitle).font(.headline)
            Chart {
                ForEach(summaries) { summary in
                    BarMark(
                        x: .value(L10n.historyChartDay, summary.day, unit: .day),
                        y: .value(L10n.historyChartMinutes, summary.minutesToTarget)
                    )
                    .foregroundStyle(summary.exceededThreshold ? Color.orange : Color.accentColor)
                    .cornerRadius(4)
                }
                RuleMark(y: .value(L10n.historyChartThreshold, SessionRules.overdueThreshold / 60))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text(L10n.historyChartThreshold).font(.caption2).foregroundStyle(.secondary)
                    }
            }
            .chartXScale(domain: domain)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 2)) {
                    AxisValueLabel(format: .dateTime.day().month(.defaultDigits))
                }
            }
            .chartYAxisLabel(L10n.historyChartMinutes)
            .frame(height: 200)
        }
        .padding(.vertical, 8)
    }
}
