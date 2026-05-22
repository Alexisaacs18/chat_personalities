import Foundation
import SwiftData

@Model
final class Conversation {
    @Attribute(.unique) var id: UUID
    var title: String
    var personaId: String
    var intensityCore: Double
    var intensitySpeech: Double
    var intensityVocab: Double
    var intensityFewShots: Double
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \StoredMessage.conversation)
    var messages: [StoredMessage] = []

    init(
        id: UUID = UUID(),
        title: String = "New Chat",
        personaId: String = Persona.presetID("wook"),
        intensities: LayerIntensities = .full,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.personaId = personaId
        self.intensityCore = intensities.coreIdentity
        self.intensitySpeech = intensities.speechPatterns
        self.intensityVocab = intensities.vocabulary
        self.intensityFewShots = intensities.fewShots
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var layerIntensities: LayerIntensities {
        get {
            LayerIntensities(
                coreIdentity: intensityCore,
                speechPatterns: intensitySpeech,
                vocabulary: intensityVocab,
                fewShots: intensityFewShots
            )
        }
        set {
            intensityCore = newValue.coreIdentity
            intensitySpeech = newValue.speechPatterns
            intensityVocab = newValue.vocabulary
            intensityFewShots = newValue.fewShots
        }
    }
}

@Model
final class StoredMessage {
    var id: UUID
    var role: String
    var content: String
    var createdAt: Date
    var conversation: Conversation?

    init(id: UUID = UUID(), role: String, content: String, createdAt: Date = .now) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }

    var dto: ChatMessageDTO {
        ChatMessageDTO(id: id, role: role, content: content, createdAt: createdAt)
    }
}

@Model
final class CustomPersona {
    @Attribute(.unique) var id: String
    var name: String
    var coreIdentity: String
    var speechPatterns: String
    var vocabulary: String
    var negativeConstraints: String?
    var fewShotsJSON: String
    var intensityCore: Double
    var intensitySpeech: Double
    var intensityVocab: Double
    var intensityFewShots: Double
    /// Bundled starter voice (editable; use reset to restore JSON defaults).
    var isBuiltIn: Bool = false
    var createdAt: Date

    init(from persona: Persona, isBuiltIn: Bool = false) {
        self.id = persona.id
        self.name = persona.name
        self.coreIdentity = persona.layers.coreIdentity
        self.speechPatterns = persona.layers.speechPatterns
        self.vocabulary = persona.layers.vocabulary
        self.negativeConstraints = persona.layers.negativeConstraints
        self.fewShotsJSON = (try? String(data: JSONEncoder().encode(persona.layers.fewShots), encoding: .utf8)) ?? "[]"
        self.intensityCore = persona.intensities.coreIdentity
        self.intensitySpeech = persona.intensities.speechPatterns
        self.intensityVocab = persona.intensities.vocabulary
        self.intensityFewShots = persona.intensities.fewShots
        self.isBuiltIn = isBuiltIn || persona.isPreset
        self.createdAt = .now
    }

    func toPersona() -> Persona {
        let shots: [FewShot] = {
            guard let data = fewShotsJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([FewShot].self, from: data) else { return [] }
            return decoded
        }()
        return Persona(
            id: id,
            name: name,
            isPreset: isBuiltIn,
            layers: PersonaLayers(
                coreIdentity: coreIdentity,
                speechPatterns: speechPatterns,
                vocabulary: vocabulary,
                negativeConstraints: negativeConstraints,
                fewShots: shots
            ),
            intensities: LayerIntensities(
                coreIdentity: intensityCore,
                speechPatterns: intensitySpeech,
                vocabulary: intensityVocab,
                fewShots: intensityFewShots
            )
        )
    }

    func update(from persona: Persona) {
        name = persona.name
        coreIdentity = persona.layers.coreIdentity
        speechPatterns = persona.layers.speechPatterns
        vocabulary = persona.layers.vocabulary
        negativeConstraints = persona.layers.negativeConstraints
        if let data = try? JSONEncoder().encode(persona.layers.fewShots),
           let json = String(data: data, encoding: .utf8) {
            fewShotsJSON = json
        }
        intensityCore = persona.intensities.coreIdentity
        intensitySpeech = persona.intensities.speechPatterns
        intensityVocab = persona.intensities.vocabulary
        intensityFewShots = persona.intensities.fewShots
    }
}
