import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

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
                Button(action: onFinish) {
                    Text(L10n.onboardingAgree).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("onboardingAgree")
                .padding(24)
            }
        }
        .interactiveDismissDisabled()
    }
}
