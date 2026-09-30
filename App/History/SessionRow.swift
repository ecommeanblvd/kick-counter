import KickCore
import KickData
import SwiftUI

struct SessionRow: View {
    let session: KickSession

    var body: some View {
        let state = session.state
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(state.startedAt, format: .dateTime.hour().minute())
                    .font(.headline)
                Text(L10n.historyRowCount(state.count))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if state.status == .completed, let duration = state.duration {
                    Text(Formatting.duration(duration)).font(.body.monospacedDigit())
                }
                statusLabel(state)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("sessionRow")
    }

    @ViewBuilder
    private func statusLabel(_ state: SessionState) -> some View {
        switch state.status {
        case .completed:
            Label(L10n.historyStatusCompleted, systemImage: state.exceededThreshold ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(state.exceededThreshold ? Color.orange : Color.green)
        case .cancelled, .active:
            Label(L10n.historyStatusCancelled, systemImage: "xmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
