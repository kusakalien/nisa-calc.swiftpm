import SwiftUI

@main
struct NisaCalcApp: App {
    @State private var store = NISAStore()
    @State private var storeManager = StoreManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(storeManager)
        }
    }
}
