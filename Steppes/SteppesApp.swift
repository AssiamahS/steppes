import SwiftUI
import UIKit

@main
struct SteppesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: phase) { _, newPhase in
            if newPhase == .active { StepStore.shared.foreground() }
        }
        .backgroundTask(.appRefresh(StepStore.refreshTaskID)) {
            await StepStore.shared.backgroundRefresh()
        }
    }
}

/// HealthKit background delivery requires the observer query to be registered
/// at launch, before didFinishLaunching returns — that's the one job of this delegate.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        StepStore.shared.bootstrap()
        return true
    }
}
