import SwiftUI
import UIKit

struct ICloudSignInView: View {
    var body: some View {
        ZStack {
            Color.surfaceBackground.ignoresSafeArea()

            VStack(spacing: 18) {
                Text("Sign in to iCloud")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text("FitPinky needs iCloud to create or join your shared group.")
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)

                Button {
                    guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(settingsURL)
                } label: {
                    Text("Open Settings")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.brand, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(24)
        }
    }
}
