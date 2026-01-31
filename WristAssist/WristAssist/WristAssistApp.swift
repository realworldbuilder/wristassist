import SwiftUI

@main
struct WristAssistApp: App {
    @StateObject private var connectivityManager = PhoneConnectivityManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivityManager)
        }
    }
}
