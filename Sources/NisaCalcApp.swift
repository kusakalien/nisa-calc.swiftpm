import SwiftUI

@main
struct NisaCalcApp: App {
    @State private var store = NISAStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
