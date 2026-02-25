import SwiftUI

struct OnboardingView: View {
    @Environment(ActiveDataService.self) private var dataService

    private var pendingInviteCode: String? {
        UserDefaults.standard.string(forKey: CloudKitService.pendingInviteCodeKey)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.surfaceBackground.ignoresSafeArea()
                content
                    .padding(.horizontal, 24)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let code = pendingInviteCode, !code.isEmpty {
            InviteCodeView(inviteCode: code)
        } else {
            VStack(spacing: 22) {
                Spacer()

                Text("Welcome to FitPinky")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Create a group with your partner or join with an invite code.")
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 14) {
                    NavigationLink(destination: CreateGroupNameView()) {
                        onboardingButtonLabel("Create a Group")
                    }

                    NavigationLink(destination: JoinGroupCodeView()) {
                        onboardingButtonLabel("Join a Group")
                    }
                }
                .padding(.top, 10)

                OnboardingDebugPanel()

                Spacer()
            }
        }
    }

    private func onboardingButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.brand, in: RoundedRectangle(cornerRadius: 14))
    }
}
