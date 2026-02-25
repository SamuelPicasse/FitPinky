import SwiftUI

@main
struct FitPinkyApp: App {
    @State private var dataService = MockDataService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(dataService)
        }
    }
}
