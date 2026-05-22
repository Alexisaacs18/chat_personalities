import Foundation
import SwiftData

enum PersonaStore {
    /// Seeds bundled presets into SwiftData on first launch so every voice is editable.
    static func seedBuiltInsIfNeeded(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<CustomPersona>())) ?? []
        let existingIds = Set(existing.map(\.id))
        for preset in PresetLoader.loadAll() where !existingIds.contains(preset.id) {
            context.insert(CustomPersona(from: preset, isBuiltIn: true))
        }
        try? context.save()
    }

    static func allPersonas(from stored: [CustomPersona]) -> [Persona] {
        stored
            .map { $0.toPersona() }
            .sorted { lhs, rhs in
                if lhs.isPreset != rhs.isPreset { return lhs.isPreset && !rhs.isPreset }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    static func persona(byId id: String, in personas: [Persona]) -> Persona? {
        personas.first { $0.id == id }
    }

    static func bundleDefault(id: String) -> Persona? {
        PresetLoader.loadAll().first { $0.id == id }
    }

    static func save(_ persona: Persona, isBuiltIn: Bool, context: ModelContext) {
        let descriptor = FetchDescriptor<CustomPersona>(
            predicate: #Predicate { $0.id == persona.id }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.update(from: persona)
            existing.isBuiltIn = isBuiltIn
        } else {
            context.insert(CustomPersona(from: persona, isBuiltIn: isBuiltIn))
        }
        try? context.save()
    }

    static func resetBuiltIn(id: String, context: ModelContext) -> Persona? {
        guard let defaultPersona = bundleDefault(id: id) else { return nil }
        save(defaultPersona, isBuiltIn: true, context: context)
        return defaultPersona
    }

    static func delete(id: String, context: ModelContext) {
        let descriptor = FetchDescriptor<CustomPersona>(
            predicate: #Predicate { $0.id == id }
        )
        if let item = try? context.fetch(descriptor).first, !item.isBuiltIn {
            context.delete(item)
            try? context.save()
        }
    }
}
