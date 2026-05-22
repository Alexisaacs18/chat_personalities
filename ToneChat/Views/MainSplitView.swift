import SwiftData
import SwiftUI

struct MainSplitView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    @Query(sort: \CustomPersona.createdAt, order: .forward) private var customStored: [CustomPersona]

    @State private var selectedConversationId: UUID?
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    private var personas: [Persona] {
        PersonaStore.allPersonas(from: customStored)
    }

    private var selectedConversation: Conversation? {
        guard let id = selectedConversationId else { return nil }
        return conversations.first { $0.id == id }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                personas: personas,
                conversations: conversations,
                selectedConversationId: $selectedConversationId,
                onNewChat: { createConversation(select: true) },
                onDelete: deleteConversations
            )
        } detail: {
            if let conversation = selectedConversation {
                ChatView(conversation: conversation, personas: personas)
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
        PersonaStore.seedBuiltInsIfNeeded(context: modelContext)
        migrateLegacyVoiceIds()
        if VoicePreferences.defaultVoiceId.isEmpty {
            VoicePreferences.defaultVoiceId = personas.first?.id ?? PresetLoader.defaultPersona.id
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
        let persona = PersonaStore.persona(byId: voiceId, in: personas) ?? personas.first ?? PresetLoader.defaultPersona
        let conversation = Conversation(personaId: persona.id)
        if let stored = PersonaStore.persona(byId: persona.id, in: personas) {
            conversation.layerIntensities = stored.intensities
        }
        modelContext.insert(conversation)
        try? modelContext.save()
        if select {
            selectedConversationId = conversation.id
        }
    }
}
