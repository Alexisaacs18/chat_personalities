import SwiftData
import SwiftUI

@main
struct ToneChatApp: App {
    @StateObject private var auth = AuthService()

    var sharedModelContainer: ModelContainer = ModelPersistence.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
        }
        .modelContainer(sharedModelContainer)
    }
}
