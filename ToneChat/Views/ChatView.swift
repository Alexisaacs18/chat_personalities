import SwiftData
import SwiftUI

struct ChatView: View {
    @Bindable var conversation: Conversation
    let personas: [Persona]

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var auth: AuthService
    @StateObject private var viewModel = ChatViewModel()
    @State private var showSettings = false

    private var currentPersona: Persona {
        PersonaStore.persona(byId: conversation.personaId, in: personas)
            ?? personas.first
            ?? PresetLoader.defaultPersona
    }

    private var sortedMessages: [StoredMessage] {
        conversation.messages.sorted { $0.createdAt < $1.createdAt }
    }

    private var canSend: Bool {
        !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if sortedMessages.isEmpty {
                            emptyState
                                .frame(minHeight: 360)
                        }

                        ForEach(Array(sortedMessages.enumerated()), id: \.element.id) { index, message in
                            ChatMessageRow(
                                role: message.role,
                                content: bubbleContent(for: message),
                                voiceName: currentPersona.name,
                                isStreaming: isStreamingMessage(message),
                                showVoiceLabel: showVoiceLabel(at: index, message: message)
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.vertical, AppTheme.spacingSM)
                }
                .defaultScrollAnchor(.bottom)
                .onChange(of: sortedMessages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: viewModel.streamingAssistantText) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
            }

            if let error = viewModel.errorMessage {
                errorBanner(error)
            }

            ChatComposerView(
                text: $viewModel.inputText,
                isStreaming: viewModel.isStreaming,
                canSend: canSend,
                onSend: sendMessage,
                onStop: { viewModel.cancelStream() }
            )
        }
        .themeBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button {
                    showSettings = true
                } label: {
                    voiceChip
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView(activeConversation: conversation)
            }
        }
        .onDisappear {
            viewModel.cancelStream()
        }
    }

    private var voiceChip: some View {
        HStack(spacing: 6) {
            Image(systemName: AppTheme.icon(for: currentPersona.id))
                .font(.caption)
            Text(currentPersona.name)
                .font(.subheadline.weight(.medium))
            Image(systemName: "chevron.down")
                .font(.caption2)
        }
        .foregroundStyle(AppTheme.textPrimary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(AppTheme.surfaceElevated)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppTheme.border, lineWidth: 1))
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.spacingMD) {
            Image(systemName: AppTheme.icon(for: currentPersona.id))
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.accent)
            Text("Talking with \(currentPersona.name)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Try asking:")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                suggestion("What’s good to listen to tonight?")
                suggestion("Tell me a story from the rail.")
                suggestion("How’s your day going?")
            }
            .padding(.top, AppTheme.spacingXS)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppTheme.spacingLG)
    }

    private func suggestion(_ text: String) -> some View {
        Button {
            viewModel.inputText = text
            sendMessage()
        } label: {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppTheme.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(AppTheme.errorText)
            .padding(.horizontal, AppTheme.spacingMD)
            .padding(.vertical, AppTheme.spacingSM)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.errorBackground)
            .padding(.horizontal, AppTheme.spacingMD)
    }

    private func sendMessage() {
        viewModel.send(
            conversation: conversation,
            persona: currentPersona,
            modelContext: modelContext,
            auth: auth
        )
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = sortedMessages.last {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private func bubbleContent(for message: StoredMessage) -> String {
        if isStreamingMessage(message), !viewModel.streamingAssistantText.isEmpty {
            return viewModel.streamingAssistantText
        }
        return message.content
    }

    private func isStreamingMessage(_ message: StoredMessage) -> Bool {
        viewModel.isStreaming
            && message.role == "assistant"
            && message.id == sortedMessages.last?.id
    }

    private func showVoiceLabel(at index: Int, message: StoredMessage) -> Bool {
        guard message.role == "assistant" else { return false }
        if index == 0 { return true }
        return sortedMessages[index - 1].role == "user"
    }
}
