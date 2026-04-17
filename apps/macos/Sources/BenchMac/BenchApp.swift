import SwiftUI

@main
struct BenchApp: App {
    var body: some Scene {
        WindowGroup("Bench") {
            ContentView()
                .frame(minWidth: 1040, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
