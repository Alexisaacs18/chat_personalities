import Foundation

struct VoiceTestResult: Identifiable {
    let id = UUID()
    let prompt: String
    let reply: String
    let error: String?
}

enum VoiceTestService {
    static let prompts = [
        "I'm tired",
        "Explain quantum entanglement in simple terms.",
        "What do you think of politics?",
    ]

    @MainActor
    static func runTests(persona: Persona, auth: AuthService) async -> [VoiceTestResult] {
        let api = ChatAPIClient(baseURL: AppConfig.apiBaseURL)
        var results: [VoiceTestResult] = []

        for prompt in prompts {
            let request = ChatRequest(
                conversationId: "voice-test-\(UUID().uuidString)",
                persona: persona.payload,
                messages: [ChatMessageDTO(role: "user", content: prompt)],
                highFidelity: VoicePreferences.highFidelityReplies
            )
            let replyBox = StreamReplyBox()
            do {
                try await api.streamChat(request: request, auth: auth) { delta in
                    replyBox.append(delta)
                }
                results.append(VoiceTestResult(prompt: prompt, reply: replyBox.value, error: nil))
            } catch {
                results.append(VoiceTestResult(
                    prompt: prompt,
                    reply: "",
                    error: error.localizedDescription
                ))
            }
        }

        return results
    }
}

/// Thread-safe accumulator for streaming deltas from a `@Sendable` callback.
private final class StreamReplyBox: @unchecked Sendable {
    private let lock = NSLock()
    private var parts: [String] = []

    func append(_ delta: String) {
        lock.lock()
        parts.append(delta)
        lock.unlock()
    }

    var value: String {
        lock.lock()
        defer { lock.unlock() }
        return parts.joined()
    }
}
