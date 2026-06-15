import SwiftUI

@main
struct SPSEXYApp: App {
    @StateObject private var auth = GoogleAuth()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
                .task { await auth.restore() }
        }
    }
}
