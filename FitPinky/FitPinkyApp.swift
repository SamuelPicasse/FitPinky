import SwiftUI

@main
struct FitPinkyApp: App {
    @State private var dataService = ActiveDataService()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if dataService.isLoading {
                    LaunchScreenView()
                } else if dataService.needsAuthentication {
                    ICloudSignInView()
                } else if !dataService.hasGroup {
                    OnboardingView()
                } else {
                    ContentView()
                }
            }
                .environment(dataService)
                .task { await dataService.setup() }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task { await dataService.ensureCurrentWeekGoal() }
                    }
                }
                .preferredColorScheme(.dark)
        }
    }
}
