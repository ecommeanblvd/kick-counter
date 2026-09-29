import SwiftUI

/// The large tap target. Fills a progress ring as movements are recorded.
struct KickButton: View {
    let count: Int
    let target: Int
    let isActive: Bool
    let action: () -> Void

    private var progress: Double { Double(count) / Double(target) }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.12))
                Circle()
                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 16)
                    .padding(8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(8)
                VStack(spacing: 4) {
                    Text("\(count)")
                        .font(.system(size: 88, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text(isActive ? L10n.counterProgress(count, target) : L10n.counterStart)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .monospacedDigit()
            }
        }
        .buttonStyle(PressableCircleStyle())
        .frame(maxWidth: 340)
        .aspectRatio(1, contentMode: .fit)
        .animation(.spring(duration: 0.3), value: count)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.counterA11yButton)
        .accessibilityValue(L10n.counterA11yValue(count, target))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("kickButton")
    }
}

private struct PressableCircleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
