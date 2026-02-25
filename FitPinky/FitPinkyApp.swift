import SwiftUI
import CloudKit
import UserNotifications

@main
struct FitPinkyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
                .task {
                    await dataService.setup()
                    #if !targetEnvironment(simulator)
                    if dataService.hasGroup {
                        await requestNotificationPermission()
                        await dataService.setupSubscriptions()
                    }
                    #endif
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task {
                            await dataService.performDeltaSync()
                            await dataService.ensureCurrentWeekGoal()
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .cloudKitRemoteNotification)) { _ in
                    Task { await dataService.performDeltaSync() }
                }
                .preferredColorScheme(.dark)
        }
    }

    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        } catch {
            // User denied notifications — that's fine
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        NotificationCenter.default.post(name: .cloudKitRemoteNotification, object: nil, userInfo: userInfo)
        return .newData
    }
}

extension Notification.Name {
    static let cloudKitRemoteNotification = Notification.Name("FitPinky.cloudKitRemoteNotification")
}
