import SwiftUI

struct MedicalInfoView: View {
    var body: some View {
        ScrollView {
            Text(L10n.medicalBody)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle(L10n.medicalTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}
