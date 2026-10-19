import SwiftUI

@main
struct WeightWidgetApp: App {
    @State private var model = WeightModel()
    @State private var showingAdd = false

    var body: some Scene {
        WindowGroup {
            ContentView(showingAdd: $showingAdd)
                .environment(model)
                .task { await model.start() }
                .onOpenURL { url in
                    if url == AppConfig.addURL { showingAdd = true }
                }
        }
    }
}
