import SwiftUI

struct SidebarView: View {
    let presets: [Persona]
    let customPersonas: [Persona]
    let conversations: [Conversation]
    @Binding var selectedConversationId: UUID?
    var onNewChat: () -> Void
    var onDelete: (IndexSet) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onNewChat) {
                Label("New chat", systemImage: "square.and.pencil")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.spacingSM)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
            .padding(.horizontal, AppTheme.spacingMD)
            .padding(.top, AppTheme.spacingSM)
            .padding(.bottom, AppTheme.spacingSM)

            List(selection: $selectedConversationId) {
                if conversations.isEmpty {
                    Text("No conversations yet")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(conversations) { conversation in
                        NavigationLink(value: conversation.id) {
                            SidebarConversationRow(
                                title: conversation.title,
                                voiceName: voiceName(for: conversation.personaId),
                                isSelected: selectedConversationId == conversation.id
                            )
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(
                            top: 2,
                            leading: AppTheme.spacingSM,
                            bottom: 2,
                            trailing: AppTheme.spacingSM
                        ))
                    }
                    .onDelete(perform: onDelete)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            Divider()
                .overlay(AppTheme.border)

            NavigationLink {
                SettingsView(presets: presets, customPersonas: customPersonas)
            } label: {
                Label("Settings", systemImage: "gearshape")
                    .font(.body)
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppTheme.spacingMD)
            }
        }
        .background(AppTheme.surface)
        .navigationTitle("ToneChat")
    }

    private func voiceName(for id: String) -> String {
        PresetLoader.persona(byId: id, custom: customPersonas)?.name ?? "Voice"
    }
}
