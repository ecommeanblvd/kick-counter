import KickCore
import SwiftUI

/// Tab 1 (default): where the pregnancy stands today, the baby this week,
/// tips, the next check-up and — from week 28 — a nudge to count kicks.
struct PregnancyHomeView: View {
    let onOpenCounter: () -> Void

    @Environment(AppointmentCoordinator.self) private var appointments
    @Environment(\.contentLibrary) private var library
    @AppStorage(SettingsKey.dueDate, store: AppGroup.defaults) private var dueDate: Double = 0
    @State private var showingDateSheet = false
    @State private var detailWeek: Int?

    private let language = ContentLanguage.current
    private let visibility = BuildFlags.contentVisibility

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(L10n.pregnancyTitle)
                .toolbar {
                    if dueDate > 0 {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                showingDateSheet = true
                            } label: {
                                Label(L10n.pregnancyEditDate, systemImage: "calendar")
                            }
                            .accessibilityIdentifier("pregnancyEditDateButton")
                        }
                    }
                }
                .navigationDestination(item: $detailWeek) { week in
                    WeekDetailView(currentWeek: week)
                }
                .sheet(isPresented: $showingDateSheet) {
                    PregnancyDateSheet()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if dueDate <= 0 {
            ContentUnavailableView {
                Label(L10n.pregnancyEmptyTitle, systemImage: "calendar.badge.plus")
            } description: {
                Text(L10n.pregnancyEmptyBody)
            } actions: {
                Button(L10n.pregnancyEmptyAction) { showingDateSheet = true }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("pregnancyAddDateButton")
            }
        } else if let timeline = PregnancyTimeline(dueDate: Date(timeIntervalSince1970: dueDate), now: AppClock.now()) {
            ScrollView {
                cards(for: timeline)
                    .padding()
            }
        } else {
            ContentUnavailableView {
                Label(L10n.pregnancyInvalidTitle, systemImage: "exclamationmark.triangle")
            } description: {
                Text(L10n.pregnancyInvalidBody)
            } actions: {
                Button(L10n.pregnancyEditDate) { showingDateSheet = true }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("pregnancyFixDateButton")
            }
        }
    }

    private func cards(for timeline: PregnancyTimeline) -> some View {
        let contentWeek = WeeklyContentLibrary.clampedWeek(timeline.week.weeks)
        let display = library?.display(forWeek: contentWeek, visibility: visibility)
        return VStack(spacing: 16) {
            WeekProgressCard(timeline: timeline)

            switch display {
            case .content(let week, let pendingReview)?:
                Button { detailWeek = contentWeek } label: {
                    BabySizeCard(week: week, language: language, pendingReview: pendingReview)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("babySizeCard")

                Button { detailWeek = contentWeek } label: {
                    WeekTipsCard(tips: Array(week.tips.items(language).prefix(2)))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("weekTipsCard")
            case .underReview?:
                Button { detailWeek = contentWeek } label: { UnderReviewCard() }
                    .buttonStyle(.plain)
            case nil:
                EmptyView()
            }

            NextAppointmentCard(
                appointment: appointments.nextAppointment,
                milestone: library?.upcomingMilestones(atWeek: timeline.week.weeks, visibility: visibility).first,
                language: language
            )
            .accessibilityIdentifier("nextAppointmentCard")

            if timeline.isKickCountingWeek {
                Button(action: onOpenCounter) { KickCountCard() }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("kickCountCard")
            }
        }
    }
}
