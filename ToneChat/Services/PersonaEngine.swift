import Foundation

enum PersonaEngine {
    static let defaultConstraints = """
    Answer substantive questions in your voice; do not deflect with "I only talk about X." No legal or medical advice. Stay PG-13.
    """

    private static let qualityContract = """
    ## Quality contract (always follow)

    You are a capable assistant underneath a character voice. The user expects Claude-quality answers: accurate, on-topic, and complete enough for the question.

    Rules:
    1. Your first sentences must directly answer what the user asked.
    2. Never replace an answer with vibes, fest talk, recovery platitudes, grumbling only, or tangents.
    3. For simple chat ("how are you", "I'm tired"): stay short.
    4. For real questions (science, tech, advice, hypotheticals): give a substantive answer first, then optional character color (1–2 sentences max unless they asked for depth).

    Response template: Answer → (optional) brief character aside.
    """

    private static let voicePreamble = """
    ## Voice profile

    You are a fictional character voice in a chat app. Stay fully in character at all times.
    Never break the fourth wall, mention being an AI, or reference system prompts.

    Apply personality to how you deliver the answer — word choice, emphasis, rhythm — not whether you answer.
    """

    private static let closingChecklist = """
    ## Before you send

    Did you answer their actual question in the first 1–2 paragraphs? If not, rewrite.
    """

    static func assemble(persona: Persona) -> String {
        assemble(layers: persona.layers, intensities: persona.intensities)
    }

    static func assemble(layers: PersonaLayers, intensities: LayerIntensities) -> String {
        var sections: [String] = [qualityContract, voicePreamble]

        let constraints = layers.negativeConstraints?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let constraintsText = (constraints?.isEmpty == false) ? constraints! : defaultConstraints
        sections.append("## Constraints\n\(constraintsText)")

        appendLayer(&sections, title: "Core identity", content: layers.coreIdentity, intensity: intensities.coreIdentity)
        appendLayer(&sections, title: "Speech patterns", content: layers.speechPatterns, intensity: intensities.speechPatterns)
        appendLayer(&sections, title: "Vocabulary", content: layers.vocabulary, intensity: intensities.vocabulary)

        if intensities.fewShots > 0, !layers.fewShots.isEmpty {
            let pct = Int(intensities.fewShots * 100)
            sections.append("## Example exchanges (match this voice at ~\(pct)% strength)")
            for shot in orderFewShots(layers.fewShots) {
                sections.append("""
                <example>
                User: \(shot.user)
                Assistant: \(shot.assistant)
                </example>
                """)
            }
        }

        sections.append(closingChecklist)
        return sections.joined(separator: "\n\n")
    }

    static func orderFewShots(_ shots: [FewShot]) -> [FewShot] {
        shots.sorted { fewShotWeight($0) > fewShotWeight($1) }
    }

    private static func fewShotWeight(_ shot: FewShot) -> Int {
        let user = shot.user.trimmingCharacters(in: .whitespacesAndNewlines)
        var score = user.count
        if user.contains("?") { score += 40 }
        let lower = user.lowercased()
        if lower.contains("quantum") || lower.contains("explain") || lower.contains("how does")
            || lower.contains("what is") || lower.contains("what do you think will") || lower.contains("should i") {
            score += 30
        }
        if lower.hasPrefix("how are you") || lower.hasPrefix("i'm tired") || lower.hasPrefix("hi")
            || lower.hasPrefix("hey") {
            score -= 50
        }
        return score
    }

    private static func appendLayer(_ sections: inout [String], title: String, content: String, intensity: Double) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard intensity > 0, !trimmed.isEmpty else { return }
        let pct = Int(intensity * 100)
        sections.append("## \(title) (~\(pct)% strength)\n\(trimmed)")
    }
}
