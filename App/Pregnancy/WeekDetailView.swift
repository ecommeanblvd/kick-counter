import KickCore
import SwiftUI

/// Week-by-week pages 4…42, opening on the current week.
struct WeekDetailView: View {
    let currentWeek: Int
    @State private var selection: Int

    init(currentWeek: Int) {
        self.currentWeek = currentWeek
        _selection = State(initialValue: currentWeek)
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(Array(WeeklyContentLibrary.weekRange), id: \.self) { week in
                WeekPage(week: week, isCurrentWeek: week == currentWeek)
                    .tag(week)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color(.systemBackground))
        .navigationTitle(L10n.weekTitle(selection))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WeekPage: View {
    let week: Int
    let isCurrentWeek: Bool
    @Environment(\.contentLibrary) private var library
    private let language = ContentLanguage.current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isCurrentWeek {
                    Text(L10n.weekCurrent)
                        .font(.caption.bold())
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
                switch library?.display(forWeek: week, visibility: BuildFlags.contentVisibility) {
                case .content(let content, let pendingReview)?:
                    BabySizeCard(week: content, language: language, pendingReview: pendingReview, showsDisclosure: false)
                    WeekSection(title: L10n.weekBaby, systemImage: "figure.and.child.holdinghands", items: content.baby.items(language))
                    WeekSection(title: L10n.weekMom, systemImage: "heart.fill", items: content.mom.items(language))
                    WeekSection(title: L10n.weekTips, systemImage: "lightbulb.fill", items: content.tips.items(language))
                    WarningSection(items: content.warnings.items(language))
                case .underReview?:
                    UnderReviewCard()
                case nil:
                    EmptyView()
                }
            }
            .padding()
        }
    }
}

private struct WeekSection: View {
    let title: String
    let systemImage: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(Color.accentColor)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: "•").accessibilityHidden(true)
                    Text(item)
                }
                .font(.body)
            }
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}

/// "When to get care right away" — orange like the 2-hour overdue banner.
private struct WarningSection: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.weekWarnings, systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: "•").accessibilityHidden(true)
                    Text(item)
                }
                .font(.body)
            }
        }
        .card(tint: Color.orange.opacity(0.12))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("weekWarnings")
    }
}
