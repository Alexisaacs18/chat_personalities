import AuthenticationServices
import SwiftData
import SwiftUI

struct SettingsView: View {
    /// When set (e.g. opened from the chat voice chip), voice changes apply to this chat only.
    var activeConversation: Conversation?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthService
    @Query(sort: \CustomPersona.createdAt, order: .forward) private var customStored: [CustomPersona]
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]

    @State private var selectedVoiceId: String = VoicePreferences.defaultVoiceId
    @State private var showBuilder = false
    @State private var editingPersona: Persona?
    @State private var isDeleting = false
    @State private var deleteError: String?

    private var personas: [Persona] {
        PersonaStore.allPersonas(from: customStored)
    }

    private var voiceSectionFooter: String {
        if activeConversation != nil {
            return "Tap a voice to use it in this chat. Use the pencil to edit any voice."
        }
        return "Default for new chats. Tap the pencil to edit name, layers, examples, and intensities."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacingLG) {
                voiceSection
                intensitySection
                chatQualitySection
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
        .onAppear { syncSelectedVoiceId() }
        .onChange(of: activeConversation?.personaId) { _, _ in syncSelectedVoiceId() }
        .sheet(isPresented: $showBuilder) {
            NavigationStack {
                PersonaBuilderView()
                    .environmentObject(auth)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showBuilder = false }
                        }
                    }
            }
        }
        .sheet(item: $editingPersona) { persona in
            NavigationStack {
                PersonaBuilderView(persona: persona, isBuiltIn: persona.isPreset)
                    .environmentObject(auth)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { editingPersona = nil }
                        }
                    }
            }
        }
    }

    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            sectionHeader("Voices", footer: voiceSectionFooter)

            ForEach(personas) { persona in
                VoiceCardRow(
                    persona: persona,
                    isSelected: persona.id == selectedVoiceId,
                    onSelect: { selectVoice(persona) },
                    onEdit: { editingPersona = persona }
                )
                .animation(.easeInOut(duration: 0.2), value: selectedVoiceId)
            }

            Button {
                showBuilder = true
            } label: {
                Label("Create new voice", systemImage: "plus.circle")
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
            sectionHeader(
                "Voice intensity",
                footer: "Quick tweak for the selected voice. Same sliders are in the full editor (pencil)."
            )

            if PersonaStore.persona(byId: selectedVoiceId, in: personas) != nil {
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

    private var chatQualitySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            sectionHeader(
                "Reply quality",
                footer: "High fidelity drafts an accurate answer first, then applies your voice. Slower and counts as 2 messages toward your limit."
            )

            Toggle("High fidelity replies", isOn: Binding(
                get: { VoicePreferences.highFidelityReplies },
                set: { VoicePreferences.highFidelityReplies = $0 }
            ))
            .tint(AppTheme.accent)
            .padding(AppTheme.spacingMD)
            .background(AppTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusCard, style: .continuous))
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
                VoiceListView()
                    .environmentObject(auth)
            } label: {
                HStack {
                    Text("Manage all voices")
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

    private func syncSelectedVoiceId() {
        selectedVoiceId = activeConversation?.personaId ?? VoicePreferences.defaultVoiceId
    }

    private func selectVoice(_ persona: Persona) {
        selectedVoiceId = persona.id

        if let activeConversation {
            activeConversation.personaId = persona.id
            activeConversation.layerIntensities = persona.intensities
            try? modelContext.save()
        } else {
            VoicePreferences.defaultVoiceId = persona.id
        }
    }

    private func intensitiesForSelectedVoice() -> LayerIntensities {
        if let activeConversation {
            return activeConversation.layerIntensities
        }
        if let persona = PersonaStore.persona(byId: selectedVoiceId, in: personas) {
            return persona.intensities
        }
        return .full
    }

    private func applyIntensities(_ intensities: LayerIntensities) {
        if let activeConversation {
            activeConversation.layerIntensities = intensities
        } else {
            for conversation in conversations where conversation.personaId == selectedVoiceId {
                conversation.layerIntensities = intensities
            }
        }

        if var persona = PersonaStore.persona(byId: selectedVoiceId, in: personas) {
            persona.intensities = intensities
            PersonaStore.save(persona, isBuiltIn: persona.isPreset, context: modelContext)
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
