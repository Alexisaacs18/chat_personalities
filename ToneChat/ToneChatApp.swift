import SwiftData
import SwiftUI

@main
struct ToneChatApp: App {
    @StateObject private var auth = AuthService()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Conversation.self,
            StoredMessage.self,
            CustomPersona.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
        }
        .modelContainer(sharedModelContainer)
    }
}
