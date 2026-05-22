import Foundation

struct ChatMessageDTO: Codable, Identifiable, Hashable {
    var id: UUID
    var role: String
    var content: String
    var createdAt: Date

    init(id: UUID = UUID(), role: String, content: String, createdAt: Date = .now) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

struct ChatRequest: Codable {
    var conversationId: String
    var persona: PersonaPayload
    var messages: [ChatMessageDTO]
    /// Two-pass draft + stylize for higher-quality substantive answers (2× rate limit cost).
    var highFidelity: Bool = false
}

struct StreamEvent: Codable {
    var type: String
    var text: String?
    var message: String?
}
