import Foundation

struct FewShot: Codable, Hashable {
    var user: String
    var assistant: String
}

struct PersonaLayers: Codable, Hashable {
    var coreIdentity: String
    var speechPatterns: String
    var vocabulary: String
    var negativeConstraints: String?
    var fewShots: [FewShot]
}

struct LayerIntensities: Codable, Hashable {
    var coreIdentity: Double
    var speechPatterns: Double
    var vocabulary: Double
    var fewShots: Double

    static let full = LayerIntensities(
        coreIdentity: 1,
        speechPatterns: 1,
        vocabulary: 1,
        fewShots: 1
    )
}

struct Persona: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var isPreset: Bool
    var layers: PersonaLayers
    var intensities: LayerIntensities

    static func presetID(_ slug: String) -> String { "preset-\(slug)" }
}

/// Payload sent to backend
struct PersonaPayload: Codable {
    var layers: PersonaLayers
    var intensities: LayerIntensities
}

extension Persona {
    var payload: PersonaPayload {
        PersonaPayload(layers: layers, intensities: intensities)
    }
}
