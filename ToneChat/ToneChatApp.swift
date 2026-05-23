import SwiftData
import SwiftUI

@main
struct ToneChatApp: App {
    @StateObject private var auth = AuthService()
    @StateObject private var usage = UsageService()

    var sharedModelContainer: ModelContainer = ModelPersistence.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(usage)
        }
        .modelContainer(sharedModelContainer)
    }
}
