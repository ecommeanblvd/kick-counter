import KickCore
import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0
    @State private var showingPregnancyStep = false
    @State private var dateSource: PregnancyDateSource
    @State private var date: Date
    private let now: Date

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        let now = AppClock.now()
        self.now = now
        let selection = PregnancyDateInput.initialSelection(for: PregnancyProfile.load(from: AppGroup.defaults), now: now)
        _dateSource = State(initialValue: selection.source)
        _date = State(initialValue: selection.date)
    }

    private struct Page {
        let symbol: String
        let title: String
        let body: String
    }

    private var pages: [Page] {
        [
            Page(symbol: "hand.tap.fill", title: L10n.onboarding1Title, body: L10n.onboarding1Body),
            Page(symbol: "moon.stars.fill", title: L10n.onboarding2Title, body: L10n.onboarding2Body),
            Page(symbol: "stethoscope", title: L10n.onboarding3Title, body: L10n.onboarding3Body),
        ]
    }

    var body: some View {
        Group {
            if showingPregnancyStep {
                pregnancyStep
            } else {
                introPages
            }
        }
        .interactiveDismissDisabled()
    }

    private var introPages: some View {
        VStack {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    VStack(spacing: 24) {
                        Image(systemName: pages[index].symbol)
                            .font(.system(size: 72))
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)
                        Text(pages[index].title)
                            .font(.title.bold())
                            .multilineTextAlignment(.center)
                        Text(pages[index].body)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding(32)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            if page < pages.count - 1 {
                Button {
                    withAnimation { page += 1 }
                } label: {
                    Text(L10n.onboardingNext).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityIdentifier("onboardingNext")
                .padding(24)
            } else {
                Button {
                    withAnimation { showingPregnancyStep = true }
                } label: {
                    Text(L10n.onboardingAgree).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("onboardingAgree")
                .padding(24)
            }
        }
    }

    private var pregnancyStep: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text(L10n.onboarding4Title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text(L10n.onboarding4Body)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)
            .padding(.top, 32)

            Form {
                PregnancyDateForm(source: $dateSource, date: $date, now: now)
            }
            .scrollContentBackground(.hidden)

            VStack(spacing: 12) {
                Button {
                    PregnancyProfile.save(source: dateSource, date: date, to: AppGroup.defaults)
                    onFinish()
                } label: {
                    Text(L10n.commonSave).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("onboardingSaveDate")

                Button(action: onFinish) {
                    Text(L10n.onboardingLater).frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .accessibilityIdentifier("onboardingSkipDate")
            }
            .padding(24)
        }
    }
}
