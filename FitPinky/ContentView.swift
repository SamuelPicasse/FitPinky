import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showSweatCam = false

    var body: some View {
        ZStack {
            Color.surfaceBackground.ignoresSafeArea()

            TabView(selection: $selectedTab) {
                DashboardView(showSweatCam: $showSweatCam)
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(0)

                Color.clear
                    .tabItem { Label("FitCam", systemImage: "camera.fill") }
                    .tag(1)

                HistoryView()
                    .tabItem { Label("History", systemImage: "calendar") }
                    .tag(2)

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                    .tag(3)
            }
            .tint(Color.brand)
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == 1 {
                showSweatCam = true
                selectedTab = oldValue
            }
        }
        .fullScreenCover(isPresented: $showSweatCam) {
            SweatCamView()
        }
        .preferredColorScheme(.dark)
    }
}
