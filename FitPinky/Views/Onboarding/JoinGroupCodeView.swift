import SwiftUI

struct JoinGroupCodeView: View {
    @State private var code: String = ""
    @State private var showNextScreen = false

    private static let validChars: Set<Character> = Set("ABCDEFGHJKMNPQRSTUVWXYZ23456789")

    private var normalizedCode: String {
        code.uppercased()
    }

    var body: some View {
        ZStack {
            Color.surfaceBackground.ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Enter invite code")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextField("ABC123", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(.title3, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cardBorder, lineWidth: 1))
                    .onChange(of: code) { _, newValue in
                        let filtered = newValue
                            .uppercased()
                            .filter { Self.validChars.contains($0) }
                        code = String(filtered.prefix(6))
                    }

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
                .disabled(normalizedCode.count < 6)
                .opacity(normalizedCode.count < 6 ? 0.5 : 1)

                Spacer()
            }
            .padding(24)
        }
        .navigationTitle("Join Group")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showNextScreen) {
            JoinGroupNameView(code: normalizedCode)
        }
    }
}
