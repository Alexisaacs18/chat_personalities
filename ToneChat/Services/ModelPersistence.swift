import Foundation
import SwiftData

/// Creates the SwiftData container, recovering from schema mismatches after app updates.
enum ModelPersistence {
    static let schema = Schema([
        Conversation.self,
        StoredMessage.self,
        CustomPersona.self,
    ])

    static func makeContainer() -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            return container
        }

        // Typical after a TestFlight update that changes the SwiftData schema (e.g. new fields).
        clearStoreFiles()

        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            return container
        }

        // Last resort: in-memory store so the app still launches.
        let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [memory])
    }

    private static func clearStoreFiles() {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
              let contents = try? fm.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil)
        else { return }

        for url in contents {
            let name = url.lastPathComponent
            if name.hasSuffix(".store") || name.hasSuffix(".store-shm") || name.hasSuffix(".store-wal") {
                try? fm.removeItem(at: url)
            }
        }
    }
}
