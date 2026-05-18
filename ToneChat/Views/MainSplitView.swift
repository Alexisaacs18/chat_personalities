import SwiftData
import SwiftUI

struct MainSplitView: View {
    let presets: [Persona]

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    @Query(sort: \CustomPersona.createdAt, order: .reverse) private var customStored: [CustomPersona]

    @State private var selectedConversationId: UUID?
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    private var customPersonas: [Persona] {
        customStored.map { $0.toPersona() }
    }

    private var selectedConversation: Conversation? {
        guard let id = selectedConversationId else { return nil }
        return conversations.first { $0.id == id }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                presets: presets,
                customPersonas: customPersonas,
                conversations: conversations,
                selectedConversationId: $selectedConversationId,
                onNewChat: { createConversation(select: true) },
                onDelete: deleteConversations
            )
        } detail: {
            if let conversation = selectedConversation {
                ChatView(
                    conversation: conversation,
                    presets: presets,
                    customPersonas: customPersonas
                )
            } else {
                ContentUnavailableView {
                    Label("Select a chat", systemImage: "bubble.left.and.bubble.right")
                } description: {
                    Text("Choose a conversation or start a new one.")
                }
                .themeBackground()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(AppTheme.accent)
        .onAppear { bootstrapIfNeeded() }
        .onChange(of: conversations.count) { _, _ in
            if selectedConversationId == nil, let first = conversations.first {
                selectedConversationId = first.id
            }
        }
    }

    private func bootstrapIfNeeded() {
        migrateLegacyVoiceIds()
        if VoicePreferences.defaultVoiceId.isEmpty {
            VoicePreferences.defaultVoiceId = presets.first?.id ?? PresetLoader.defaultPersona.id
        }
        if conversations.isEmpty {
            createConversation(select: true)
        } else if selectedConversationId == nil {
            selectedConversationId = conversations.first?.id
        }
    }

    private func migrateLegacyVoiceIds() {
        for conversation in conversations where conversation.personaId == "preset-ozzy" {
            conversation.personaId = "preset-australian"
        }
        if VoicePreferences.defaultVoiceId == "preset-ozzy" {
            VoicePreferences.defaultVoiceId = "preset-australian"
        }
        try? modelContext.save()
    }

    private func deleteConversations(at offsets: IndexSet) {
        let ids = offsets.map { conversations[$0].id }
        for id in ids {
            if let item = conversations.first(where: { $0.id == id }) {
                modelContext.delete(item)
            }
        }
        try? modelContext.save()
        if let id = selectedConversationId, ids.contains(id) {
            selectedConversationId = conversations.first?.id
        }
    }

    private func createConversation(select: Bool) {
        let voiceId = VoicePreferences.defaultVoiceId
        let persona = PresetLoader.persona(byId: voiceId, custom: customPersonas) ?? presets.first!
        let conversation = Conversation(personaId: persona.id)
        modelContext.insert(conversation)
        try? modelContext.save()
        if select {
            selectedConversationId = conversation.id
        }
    }
}
