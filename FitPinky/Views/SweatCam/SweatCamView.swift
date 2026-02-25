import SwiftUI

struct SweatCamView: View {
    @Environment(ActiveDataService.self) private var dataService
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = SweatCamViewModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.showConfirmation, let watermarked = viewModel.watermarkedImage {
                PhotoConfirmationView(
                    image: watermarked,
                    caption: $viewModel.caption,
                    isSubmitting: viewModel.isSubmitting,
                    onConfirm: {
                        Task {
                            let success = await viewModel.confirmPhoto(dataService: dataService)
                            if success {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                dismiss()
                            }
                        }
                    },
                    onRetake: {
                        viewModel.retakePhoto()
                    }
                )
            } else if viewModel.cameraService.isAuthorized {
                cameraView
            } else {
                notAuthorizedView
            }
        }
        .task {
            await viewModel.setupCamera()
        }
        .onDisappear {
            viewModel.teardownCamera()
        }
    }

    // MARK: - Camera View

    private var cameraView: some View {
        ZStack {
            CameraPreviewView(session: viewModel.cameraService.session)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.black.opacity(0.4), in: Circle())
                    }

                    Spacer()

                    Button { viewModel.cameraService.toggleCamera() } label: {
                        Image(systemName: "camera.rotate")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.black.opacity(0.4), in: Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()

                Button {
                    Task { await viewModel.capturePhoto() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 72, height: 72)
                        Circle()
                            .stroke(.white, lineWidth: 4)
                            .frame(width: 82, height: 82)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Not Authorized

    private var notAuthorizedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.gray)
            Text("Camera Access Required")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text("FitPinky needs camera access to log your workouts. Enable it in Settings.")
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)

            Button("Close") { dismiss() }
                .foregroundStyle(.gray)
        }
    }
}
