import SwiftUI

struct PhotoConfirmationView: View {
    let image: UIImage
    @Binding var caption: String
    let isSubmitting: Bool
    let onConfirm: () -> Void
    let onRetake: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Photo preview
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                // Caption field
                TextField("Add a caption...", text: $caption)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .onChange(of: caption) { _, newValue in
                        if newValue.count > 100 {
                            caption = String(newValue.prefix(100))
                        }
                    }

                Spacer()

                // Action buttons
                HStack(spacing: 40) {
                    Button(action: onRetake) {
                        Label("Retake", systemImage: "arrow.counterclockwise")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(.white.opacity(0.15), in: Capsule())
                    }

                    Button(action: onConfirm) {
                        Group {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Label("Confirm", systemImage: "checkmark")
                                    .font(.headline)
                            }
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(.white, in: Capsule())
                    }
                    .disabled(isSubmitting)
                }
                .padding(.bottom, 40)
            }
        }
    }
}
