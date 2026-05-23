import Foundation
import SwiftData

enum PersonaStore {
    /// Seeds bundled presets into SwiftData on first launch so every voice is editable.
    static func seedBuiltInsIfNeeded(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<CustomPersona>())) ?? []
        let presetIds = Set(PresetLoader.loadAll().map(\.id))

        for preset in PresetLoader.loadAll() {
            if let row = existing.first(where: { $0.id == preset.id }) {
                row.isBuiltIn = true
                if row.name.isEmpty { row.update(from: preset) }
            } else {
                context.insert(CustomPersona(from: preset, isBuiltIn: true))
            }
        }

        for row in existing where presetIds.contains(row.id) {
            row.isBuiltIn = true
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

    @discardableResult
    static func delete(id: String, context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<CustomPersona>(
            predicate: #Predicate { $0.id == id }
        )
        guard let item = try? context.fetch(descriptor).first, !item.isBuiltIn else {
            return false
        }

        let fallbackId = PresetLoader.defaultPersona.id

        if let conversations = try? context.fetch(FetchDescriptor<Conversation>()) {
            for conversation in conversations where conversation.personaId == id {
                conversation.personaId = fallbackId
            }
        }

        if VoicePreferences.defaultVoiceId == id {
            VoicePreferences.defaultVoiceId = fallbackId
        }

        context.delete(item)
        try? context.save()
        return true
    }
}
