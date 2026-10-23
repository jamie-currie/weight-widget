import SwiftUI
import WidgetKit

@main
struct WeightWidgetApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var showingAdd = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(showingAdd: $showingAdd)
                .environment(appDelegate.model)
                .onChange(of: scenePhase, initial: true) {
                    if scenePhase == .active { WidgetCenter.shared.reloadAllTimelines() }
                }
        }
    }
}

/// Health wakes the app in the background for new readings without creating a window, so the
/// model starts watching here rather than from a view.
final class AppDelegate: NSObject, UIApplicationDelegate {
    let model = WeightModel()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Task { await model.start() }
        return true
    }
}
