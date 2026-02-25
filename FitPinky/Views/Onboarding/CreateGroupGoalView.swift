import SwiftUI

struct CreateGroupGoalView: View {
    @Environment(ActiveDataService.self) private var dataService

    let displayName: String

    @State private var weeklyGoal: Int = 4
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var inviteCode: String?
    @State private var showInviteScreen = false

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
                    createGroup()
                } label: {
                    HStack(spacing: 10) {
                        if isCreating {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isCreating ? "Creating..." : "Create Group")
                            .font(.headline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.brand, in: RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isCreating)
                .opacity(isCreating ? 0.75 : 1)

                OnboardingDebugPanel()

                Spacer()
            }
            .padding(24)
        }
        .navigationTitle("Create Group")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showInviteScreen) {
            InviteCodeView(inviteCode: inviteCode ?? "")
        }
    }

    private func createGroup() {
        errorMessage = nil
        isCreating = true

        #if targetEnvironment(simulator)
        errorMessage = "Group creation is only available on a physical device."
        isCreating = false
        #else
        Task {
            do {
                let code = try await dataService.createGroup(
                    displayName: displayName,
                    weeklyGoal: weeklyGoal
                )
                inviteCode = code
                showInviteScreen = true
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isCreating = false
        }
        #endif
    }
}
