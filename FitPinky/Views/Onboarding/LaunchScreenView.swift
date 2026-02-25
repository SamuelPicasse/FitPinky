import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            Color.surfaceBackground.ignoresSafeArea()

            VStack(spacing: 16) {
                Text("FitPinky")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Color.brand)

                ProgressView()
                    .tint(Color.brand)
            }
        }
    }
}
