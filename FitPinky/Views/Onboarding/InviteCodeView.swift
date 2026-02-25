import SwiftUI
import UIKit

struct InviteCodeView: View {
    @Environment(ActiveDataService.self) private var dataService

    let inviteCode: String

    @State private var pulse = false
    @State private var isPolling = false
    @State private var showCancelConfirmation = false

    private var shareMessage: String {
        "Join my FitPinky group with code: \(inviteCode)"
    }

    var body: some View {
        ZStack {
            Color.surfaceBackground.ignoresSafeArea()

            VStack(spacing: 22) {
                Text("Invite your partner")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text(inviteCode)
                    .font(.system(size: 42, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.brand)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cardBorder, lineWidth: 1))

                HStack(spacing: 12) {
                    ShareLink(item: shareMessage) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.brand, in: RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        UIPasteboard.general.string = inviteCode
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cardBorder, lineWidth: 1))
                    }
                }

                Text("Waiting for partner...")
                    .font(.headline)
                    .foregroundStyle(Color.textSecondary)
                    .opacity(pulse ? 0.35 : 1)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulse)

                if isPolling {
                    ProgressView()
                        .tint(Color.brand)
                }

                OnboardingDebugPanel()

                Spacer()
            }
            .padding(24)
        }
        .navigationTitle("Invite Code")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    showCancelConfirmation = true
                }
                .foregroundStyle(Color.textSecondary)
            }
        }
        .confirmationDialog(
            "Cancel invite?",
            isPresented: $showCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button("Cancel Invite", role: .destructive) {
                // Clear pending invite code and go back
                UserDefaults.standard.removeObject(forKey: "FitPinky_pendingInviteCode")
            }
            Button("Keep Waiting", role: .cancel) {}
        } message: {
            Text("Your invite code will be discarded. You can create a new group later.")
        }
        .task(id: inviteCode) {
            pulse = true
            await pollForPartner()
        }
    }

    private func pollForPartner() async {
        guard !isPolling else { return }
        isPolling = true
        defer { isPolling = false }

        #if targetEnvironment(simulator)
        return
        #else
        while !Task.isCancelled && !dataService.hasGroup {
            let foundPartner = await dataService.checkForPartner()
            if foundPartner {
                return
            }
            do {
                try await Task.sleep(nanoseconds: 5_000_000_000)
            } catch {
                return
            }
        }
        #endif
    }
}
