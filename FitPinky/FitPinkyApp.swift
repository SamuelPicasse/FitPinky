import SwiftUI

@main
struct FitPinkyApp: App {
    @State private var dataService = ActiveDataService()

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
                .preferredColorScheme(.dark)
        }
    }
}
