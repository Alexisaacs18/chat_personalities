import Foundation
import SwiftData

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var inputText = ""
    @Published var isStreaming = false
    @Published var errorMessage: String?
    @Published var streamingAssistantText = ""

    private let api = ChatAPIClient(baseURL: AppConfig.apiBaseURL)
    private var streamTask: Task<Void, Never>?

    func send(
        conversation: Conversation,
        persona: Persona,
        modelContext: ModelContext,
        auth: AuthService
    ) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        let userMessage = StoredMessage(role: "user", content: text)
        userMessage.conversation = conversation
        conversation.messages.append(userMessage)
        conversation.updatedAt = .now
        if conversation.title == "New Chat" {
            conversation.title = String(text.prefix(40))
        }
        inputText = ""
        try? modelContext.save()

        streamReply(conversation: conversation, persona: persona, modelContext: modelContext, auth: auth)
    }

    func cancelStream() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        streamingAssistantText = ""
    }

    private func streamReply(
        conversation: Conversation,
        persona: Persona,
        modelContext: ModelContext,
        auth: AuthService
    ) {
        var activePersona = persona
        activePersona.intensities = conversation.layerIntensities

        let dtos = conversation.messages
            .sorted { $0.createdAt < $1.createdAt }
            .filter { !($0.role == "assistant" && $0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            .map(\.dto)

        let request = ChatRequest(
            conversationId: conversation.id.uuidString,
            persona: activePersona.payload,
            messages: dtos,
            highFidelity: VoicePreferences.highFidelityReplies
        )

        isStreaming = true
        streamingAssistantText = ""
        errorMessage = nil

        let assistant = StoredMessage(role: "assistant", content: "")
        assistant.conversation = conversation
        conversation.messages.append(assistant)
        conversation.updatedAt = .now

        streamTask = Task { @MainActor in
            defer {
                isStreaming = false
                streamTask = nil
            }

            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask {
                        try await Task.sleep(nanoseconds: 120_000_000_000)
                        throw ChatAPIError.connection("Request timed out after 2 minutes.")
                    }
                    group.addTask {
                        try await self.api.streamChat(request: request, auth: auth) { [weak self] delta in
                            Task { @MainActor in
                                self?.streamingAssistantText += delta
                            }
                        }
                    }
                    try await group.next()
                    group.cancelAll()
                }

                assistant.content = streamingAssistantText
                if assistant.content.isEmpty {
                    conversation.messages.removeAll { $0.id == assistant.id }
                }
                try? modelContext.save()
            } catch is CancellationError {
                if !streamingAssistantText.isEmpty {
                    assistant.content = streamingAssistantText
                    try? modelContext.save()
                } else {
                    conversation.messages.removeAll { $0.id == assistant.id }
                    try? modelContext.save()
                }
            } catch {
                conversation.messages.removeAll { $0.id == assistant.id }
                try? modelContext.save()
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                }
            }
            streamingAssistantText = ""
        }
    }
}
