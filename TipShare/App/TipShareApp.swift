import SwiftUI

@main
struct TipShareApp: App {
    @State private var store = Store()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
    }
}
