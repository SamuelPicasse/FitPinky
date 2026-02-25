import SwiftUI

struct JoinGroupGoalView: View {
    @Environment(ActiveDataService.self) private var dataService

    let code: String
    let displayName: String

    @State private var weeklyGoal: Int = 4
    @State private var isJoining = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.surfaceBackground.ignoresSafeArea()

            VStack(spacing: 22) {
                Text("Set your weekly goal")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Stepper(value: $weeklyGoal, in: 1...7) {
                    Text("\(weeklyGoal) workout day\(weeklyGoal == 1 ? "" : "s")")
                        .foregroundStyle(.white)
                        .font(.headline)
                }
                .padding(14)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cardBorder, lineWidth: 1))
                .tint(Color.brand)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    joinGroup()
                } label: {
                    HStack(spacing: 10) {
                        if isJoining {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isJoining ? "Joining..." : "Join Group")
                            .font(.headline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.brand, in: RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isJoining)
                .opacity(isJoining ? 0.75 : 1)

                OnboardingDebugPanel()

                Spacer()
            }
            .padding(24)
        }
        .navigationTitle("Join Group")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func joinGroup() {
        errorMessage = nil
        isJoining = true

        #if targetEnvironment(simulator)
        errorMessage = "Group join is only available on a physical device."
        isJoining = false
        #else
        Task {
            do {
                try await dataService.joinGroup(
                    code: code,
                    displayName: displayName,
                    weeklyGoal: weeklyGoal
                )
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isJoining = false
        }
        #endif
    }
}
