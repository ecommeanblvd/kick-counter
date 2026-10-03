import KickCore
import SwiftUI

struct AppointmentRow: View {
    let record: AppointmentRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(record.title)
                    .font(.body.weight(.semibold))
                if record.isDone {
                    Label(L10n.appointmentsStatusDone, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            Text(record.date.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !record.note.isEmpty {
                Text(record.note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct MilestoneRow: View {
    let milestone: Milestone
    let language: ContentLanguage
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title.text(language))
                    .font(.subheadline.weight(.semibold))
                Text(L10n.milestoneWeeks(milestone.fromWeek, milestone.toWeek))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(milestone.detail.text(language))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if !milestone.reviewed {
                    PendingReviewBadge()
                }
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            Button(action: onAdd) {
                Label(L10n.appointmentsMilestoneAdd, systemImage: "calendar.badge.plus")
                    .labelStyle(.iconOnly)
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("addMilestoneButton")
            // The icon-only label alone is the same for every milestone; include
            // the milestone's own title so VoiceOver announces which one this is.
            .accessibilityLabel("\(L10n.appointmentsMilestoneAdd), \(milestone.title.text(language))")
        }
    }
}
