import SwiftUI
import WidgetKit

@main
struct WeightWidgetApp: App {
    @State private var model = WeightModel()
    @State private var showingAdd = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(showingAdd: $showingAdd)
                .environment(model)
                .task { await model.start() }
                .onChange(of: scenePhase, initial: true) {
                    if scenePhase == .active { WidgetCenter.shared.reloadAllTimelines() }
                }
        }
    }
}
