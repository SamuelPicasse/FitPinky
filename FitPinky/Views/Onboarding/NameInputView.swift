import SwiftUI

struct NameInputView<Destination: View>: View {
    let navigationTitle: String
    let destination: (String) -> Destination

    @State private var displayName: String = ""
    @State private var showNextScreen = false
    @FocusState private var nameFocused: Bool

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
                    .focused($nameFocused)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: .inputCornerRadius))
                    .overlay(RoundedRectangle(cornerRadius: .inputCornerRadius).stroke(Color.cardBorder, lineWidth: 1))
                    .foregroundStyle(.white)

                Button {
                    showNextScreen = true
                } label: {
                    Text("Next")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.brand, in: RoundedRectangle(cornerRadius: .inputCornerRadius))
                }
                .disabled(trimmedName.isEmpty)
                .opacity(trimmedName.isEmpty ? 0.5 : 1)

                Spacer()
            }
            .padding(24)
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { nameFocused = true }
        .navigationDestination(isPresented: $showNextScreen) {
            destination(trimmedName)
        }
    }
}
