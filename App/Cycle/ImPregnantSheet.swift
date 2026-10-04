import KickCore
import SwiftUI

/// "I'm pregnant": confirm the first day of the last period (or a due date),
/// then switch to pregnancy mode. Cycle data is kept.
struct ImPregnantSheet: View {
    @Environment(CycleCoordinator.self) private var cycle
    @Environment(\.dismiss) private var dismiss
    @State private var source: PregnancyDateSource
    @State private var date: Date
    private let now: Date

    /// Starts from the latest logged period; without one, from the stored
    /// pregnancy dates (or the usual default).
    init(lastPeriodStart: Date?, now: Date = AppClock.now()) {
        self.now = now
        if let lastPeriodStart {
            _source = State(initialValue: .lmp)
            _date = State(initialValue: PregnancyDateInput.clamp(lastPeriodStart, for: .lmp, now: now))
        } else {
            let selection = PregnancyDateInput.initialSelection(for: PregnancyProfile.load(from: AppGroup.defaults), now: now)
            _source = State(initialValue: selection.source)
            _date = State(initialValue: selection.date)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.imPregnantTitle).font(.headline)
                            Text(L10n.imPregnantBody).font(.subheadline)
                        }
                    } icon: {
                        Image(systemName: "heart.fill").foregroundStyle(Color.accentColor)
                    }
                    .accessibilityElement(children: .combine)
                }
                PregnancyDateForm(source: $source, date: $date, now: now)
                Section {
                    Text(L10n.imPregnantKeepsData)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(L10n.cycleImPregnant)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.commonCancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.commonSave) {
                        cycle.switchToPregnant(source: source, date: date)
                        dismiss()
                    }
                    .accessibilityIdentifier("imPregnantSave")
                }
            }
        }
    }
}
