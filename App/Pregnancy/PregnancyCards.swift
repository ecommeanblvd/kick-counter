import KickCore
import SwiftUI

extension View {
    /// Rounded card used across the Pregnancy and Appointments screens.
    func card(tint: Color = Color(.secondarySystemBackground)) -> some View {
        padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct WeekProgressCard: View {
    let timeline: PregnancyTimeline

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.counterWeek(timeline.week))
                .font(.title2.bold())
            Text(L10n.pregnancyTrimester(timeline.trimester.rawValue))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ProgressView(value: timeline.progress)
                .tint(timeline.isPastDue ? Color.orange : Color.accentColor)
            if timeline.isPastDue {
                Text(L10n.pregnancyPastDueTitle(timeline.daysPastDue))
                    .font(.headline)
                Text(L10n.pregnancyPastDueBody)
                    .font(.subheadline)
            } else if timeline.daysRemaining == 0 {
                Text(L10n.pregnancyDueToday)
                    .font(.headline)
            } else {
                Text(L10n.pregnancyDaysLeft(timeline.daysRemaining))
                    .font(.headline)
            }
        }
        .card(tint: timeline.isPastDue ? Color.orange.opacity(0.12) : Color(.secondarySystemBackground))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("weekProgressCard")
    }
}

struct BabySizeCard: View {
    let week: WeekContent
    let language: ContentLanguage
    let pendingReview: Bool
    var showsDisclosure = true
    @ScaledMetric(relativeTo: .largeTitle) private var emojiSize: CGFloat = 56

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Text(week.size.emoji)
                    .font(.system(size: emojiSize))
                    .accessibilityLabel(week.size.name(language))
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.pregnancyBabySize(week.size.name(language)))
                        .font(.headline)
                    HStack(spacing: 24) {
                        LabeledValue(title: L10n.pregnancyBabyLength, value: Formatting.length(cm: week.lengthCm))
                        LabeledValue(title: L10n.pregnancyBabyWeight, value: Formatting.weight(grams: week.weightG))
                    }
                }
                Spacer(minLength: 0)
                if showsDisclosure {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
            if pendingReview {
                PendingReviewBadge()
            }
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}

struct LabeledValue: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.monospacedDigit())
        }
    }
}

struct PendingReviewBadge: View {
    var body: some View {
        Label(L10n.weekPendingReview, systemImage: "stethoscope")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
            .accessibilityIdentifier("pendingReviewBadge")
    }
}

struct WeekTipsCard: View {
    let tips: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.pregnancyTipsTitle)
                .font(.headline)
            ForEach(tips, id: \.self) { tip in
                Label {
                    Text(tip)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
                .font(.subheadline)
            }
            Text(L10n.pregnancySeeWeek)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.accentColor)
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}

struct UnderReviewCard: View {
    var body: some View {
        Label(L10n.weekUnderReview, systemImage: "hourglass")
            .font(.subheadline)
            .card()
            .accessibilityElement(children: .combine)
    }
}

struct NextAppointmentCard: View {
    let appointment: AppointmentRecord?
    let milestone: Milestone?
    let language: ContentLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(L10n.pregnancyAppointmentTitle, systemImage: "calendar")
                .font(.headline)
            if let appointment {
                Text(appointment.title)
                    .font(.subheadline.weight(.semibold))
                Text(appointment.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if let milestone {
                Text(milestone.title.text(language))
                    .font(.subheadline.weight(.semibold))
                Text(L10n.pregnancyAppointmentSuggested(milestone.fromWeek, milestone.toWeek))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(L10n.pregnancyAppointmentNone)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}

struct KickCountCard: View {
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "hand.tap.fill")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.pregnancyKickCardTitle)
                    .font(.headline)
                Text(L10n.pregnancyKickCardBody)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}
