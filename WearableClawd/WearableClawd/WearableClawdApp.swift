import SwiftUI

@main
struct WearableClawdApp: App {
    @StateObject private var connectivityManager = PhoneConnectivityManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivityManager)
        }
    }
}
