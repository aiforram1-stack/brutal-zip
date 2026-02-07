import SwiftUI

@main
struct BrutalZipApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .frame(minWidth: 1200, minHeight: 780)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
