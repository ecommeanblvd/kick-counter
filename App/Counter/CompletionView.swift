import KickCore
import SwiftUI

struct CompletionView: View {
    let session: SessionState
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 88))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text(L10n.completionTitle)
                .font(.largeTitle.bold())
                .accessibilityIdentifier("completionTitle")
            if let duration = session.duration {
                Text(L10n.completionDuration(Formatting.duration(duration)))
                    .font(.title3)
            }
            if session.exceededThreshold {
                Text(L10n.completionExceeded)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
            }
            Spacer()
            Button(action: onDone) {
                Text(L10n.completionDone).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("completionDone")
        }
        .padding(24)
    }
}
