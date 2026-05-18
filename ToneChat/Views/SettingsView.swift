import AuthenticationServices
import SwiftData
import SwiftUI

struct SettingsView: View {
    let presets: [Persona]
    let customPersonas: [Persona]
    /// When set (e.g. opened from the chat voice chip), voice changes apply to this chat only.
    var activeConversation: Conversation?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthService
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]

    @State private var showBuilder = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    private var selectedVoiceId: String {
        activeConversation?.personaId ?? VoicePreferences.defaultVoiceId
    }

    private var voiceSectionFooter: String {
        if activeConversation != nil {
            return "Changes who replies in this chat. Your other conversations keep their voice."
        }
        return "Default for new chats. Tap the voice name inside a chat to change that conversation."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacingLG) {
                voiceSection
                intensitySection
                accountSection
                manageSection
                legalSection
                if let deleteError {
                    Text(deleteError)
                        .font(.caption)
                        .foregroundStyle(AppTheme.errorText)
                }
            }
            .padding(AppTheme.spacingMD)
        }
        .themeBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(isPresented: $showBuilder) {
            NavigationStack {
                PersonaBuilderView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showBuilder = false }
                        }
                    }
            }
        }
    }

    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            sectionHeader("Voice", footer: voiceSectionFooter)

            ForEach(presets) { persona in
                VoiceCardRow(
                    persona: persona,
                    isSelected: persona.id == selectedVoiceId,
                    onSelect: { selectVoice(persona) }
                )
            }

            ForEach(customPersonas) { persona in
                VoiceCardRow(
                    persona: persona,
                    isSelected: persona.id == selectedVoiceId,
                    onSelect: { selectVoice(persona) }
                )
            }

            Button {
                showBuilder = true
            } label: {
                Label("Create custom voice", systemImage: "plus.circle")
                    .font(.body)
                    .foregroundStyle(AppTheme.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppTheme.spacingMD)
                    .background(AppTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var intensitySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            sectionHeader("Voice intensity", footer: "Dial how strongly each layer comes through.")

            if PresetLoader.persona(byId: selectedVoiceId, custom: customPersonas) != nil {
                PersonaIntensityView(intensities: Binding(
                    get: { intensitiesForSelectedVoice() },
                    set: { applyIntensities($0) }
                ))
                .padding(AppTheme.spacingMD)
                .background(AppTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous))
            }
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            sectionHeader("Account")

            VStack(alignment: .leading, spacing: AppTheme.spacingMD) {
                if auth.isSignedInWithApple {
                    Label("Signed in with Apple", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                    Text("Higher message limits. Chats stay on this device.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    Button("Sign out") {
                        Task { await auth.signOut() }
                    }
                    Button("Delete account", role: .destructive) {
                        Task { await deleteAccount() }
                    }
                    .disabled(isDeleting)
                } else {
                    Text("Guest mode — lower limits. Chats saved on this device.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    SignInWithAppleButton(.signIn) { request in
                        auth.configureAppleRequest(request)
                    } onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            Task { await auth.handleAuthorization(authorization) }
                        case .failure(let error):
                            auth.authError = error.localizedDescription
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 44)
                }

                if let error = auth.authError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(AppTheme.errorText)
                }

                #if DEBUG
                Button("Dev sign-in (higher limits)") {
                    Task { await auth.signInDev() }
                }
                #endif
            }
            .padding(AppTheme.spacingMD)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous))
        }
    }

    private var manageSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            sectionHeader("Manage")
            NavigationLink {
                CustomPersonaListView()
            } label: {
                HStack {
                    Text("Edit custom voices")
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(AppTheme.spacingMD)
                .background(AppTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous))
            }
        }
    }

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            sectionHeader("About")
            Link("Privacy Policy", destination: AppConfig.privacyPolicyURL)
                .font(.body)
                .foregroundStyle(AppTheme.accent)
                .padding(AppTheme.spacingMD)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous))
        }
    }

    private func sectionHeader(_ title: String, footer: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private func selectVoice(_ persona: Persona) {
        if let activeConversation {
            activeConversation.personaId = persona.id
            try? modelContext.save()
        } else {
            VoicePreferences.defaultVoiceId = persona.id
        }
    }

    private func intensitiesForSelectedVoice() -> LayerIntensities {
        if let activeConversation {
            return activeConversation.layerIntensities
        }
        return conversations.first(where: { $0.personaId == selectedVoiceId })?.layerIntensities ?? .full
    }

    private func applyIntensities(_ intensities: LayerIntensities) {
        if let activeConversation {
            activeConversation.layerIntensities = intensities
        } else {
            for conversation in conversations where conversation.personaId == selectedVoiceId {
                conversation.layerIntensities = intensities
            }
        }
        try? modelContext.save()
    }

    private func deleteAccount() async {
        isDeleting = true
        deleteError = nil
        do {
            try await auth.deleteAccount()
        } catch {
            deleteError = error.localizedDescription
        }
        isDeleting = false
    }
}
