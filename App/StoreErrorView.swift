import SwiftUI

struct StoreErrorView: View {
    var body: some View {
        ContentUnavailableView(
            L10n.errorStoreTitle,
            systemImage: "exclamationmark.triangle",
            description: Text(L10n.errorStoreBody)
        )
    }
}
