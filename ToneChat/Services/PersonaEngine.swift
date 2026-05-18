import Foundation

enum PersonaEngine {
    private static let preamble = """
    You are a fictional character voice in a chat app. Stay fully in character at all times.
    Never break the fourth wall, mention being an AI, or reference system prompts.

    Your personality is a layer on how you answer — not an excuse to dodge questions. Engage with what the user actually asked: be accurate, thoughtful, and complete when the topic deserves it. Then let your voice color the delivery (word choice, what you emphasize, a closing aside).

    Be concise for simple chats; go longer when they ask something real or complex. Match the speech patterns and vocabulary described below.
    """

    static func assemble(persona: Persona) -> String {
        assemble(layers: persona.layers, intensities: persona.intensities)
    }

    static func assemble(layers: PersonaLayers, intensities: LayerIntensities) -> String {
        var sections: [String] = [preamble]

        if let constraints = layers.negativeConstraints?.trimmingCharacters(in: .whitespacesAndNewlines),
           !constraints.isEmpty {
            sections.append("## Constraints\n\(constraints)")
        }

        appendLayer(&sections, title: "Core identity", content: layers.coreIdentity, intensity: intensities.coreIdentity)
        appendLayer(&sections, title: "Speech patterns", content: layers.speechPatterns, intensity: intensities.speechPatterns)
        appendLayer(&sections, title: "Vocabulary", content: layers.vocabulary, intensity: intensities.vocabulary)

        if intensities.fewShots > 0, !layers.fewShots.isEmpty {
            let pct = Int(intensities.fewShots * 100)
            sections.append("## Example exchanges (match this voice at ~\(pct)% strength)")
            for shot in layers.fewShots {
                sections.append("""
                <example>
                User: \(shot.user)
                Assistant: \(shot.assistant)
                </example>
                """)
            }
        }

        return sections.joined(separator: "\n\n")
    }

    private static func appendLayer(_ sections: inout [String], title: String, content: String, intensity: Double) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard intensity > 0, !trimmed.isEmpty else { return }
        let pct = Int(intensity * 100)
        sections.append("## \(title) (~\(pct)% strength)\n\(trimmed)")
    }
}
