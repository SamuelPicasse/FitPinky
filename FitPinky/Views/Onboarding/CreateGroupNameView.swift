import SwiftUI

struct CreateGroupNameView: View {
    @State private var displayName: String = ""
    @State private var showNextScreen = false

    private var trimmedName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            Color.surfaceBackground.ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Your display name")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextField("Name", text: $displayName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cardBorder, lineWidth: 1))
                    .foregroundStyle(.white)

                Button {
                    showNextScreen = true
                } label: {
                    Text("Next")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.brand, in: RoundedRectangle(cornerRadius: 12))
                }
                .disabled(trimmedName.isEmpty)
                .opacity(trimmedName.isEmpty ? 0.5 : 1)

                Spacer()
            }
            .padding(24)
        }
        .navigationTitle("Create Group")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showNextScreen) {
            CreateGroupGoalView(displayName: trimmedName)
        }
    }
}
