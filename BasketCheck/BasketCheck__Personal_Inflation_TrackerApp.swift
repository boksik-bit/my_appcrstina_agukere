import SwiftUI

@main
struct BasketCheck__Personal_Inflation_TrackerApp: App {
    @State private var dataStore = DataStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(dataStore)
        }
    }
}
