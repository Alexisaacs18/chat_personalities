import SwiftData
import SwiftUI

struct PersonaBuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthService

    @State private var persona: Persona
    @State private var selectedTemplate: PersonaTemplate = .blank
    @State private var saveWarning: String?
    @State private var testResults: [VoiceTestResult] = []
    @State private var isTesting = false
    @State private var testError: String?
    @State private var showResetConfirm = false
    @State private var showDeleteConfirm = false

    let isNew: Bool
    let isBuiltIn: Bool

    init(persona: Persona? = nil, isBuiltIn: Bool = false) {
        if let persona {
            _persona = State(initialValue: persona)
            isNew = false
            self.isBuiltIn = isBuiltIn || persona.isPreset
        } else {
            _persona = State(initialValue: PersonaTemplate.blank.makePersona(
                named: "My Voice",
                id: UUID().uuidString
            ))
            isNew = true
            self.isBuiltIn = false
        }
    }

    var body: some View {
        Form {
            if isNew {
                Section("Start from template") {
                    Picker("Template", selection: $selectedTemplate) {
                        ForEach(PersonaTemplate.allCases) { template in
                            Text(template.title).tag(template)
                        }
                    }
                    .onChange(of: selectedTemplate) { _, template in
                        applyTemplate(template)
                    }
                }
            }

            if isBuiltIn {
                Section {
                    Text("Built-in starter voice. You can edit every field below. Use Reset to restore the original bundled version.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Name") {
                TextField("Voice name", text: $persona.name)
            }

            Section {
                PersonaIntensityView(intensities: $persona.intensities)
            } header: {
                Text("Layer intensities")
            } footer: {
                Text("How strongly each layer affects replies (0% hides a layer).")
            }

            Section {
                TextEditor(text: $persona.layers.coreIdentity)
                    .frame(minHeight: 80)
            } header: {
                Text("Layer 1 — Core identity")
            } footer: {
                Text("Who they are and what they know. Include that they can handle serious topics, not only their niche.")
            }

            Section {
                TextEditor(text: $persona.layers.speechPatterns)
                    .frame(minHeight: 80)
            } header: {
                Text("Layer 2 — Speech patterns")
            } footer: {
                Text("Short for small talk; longer and substantive when they ask a real question. Answer first, voice second.")
            }

            Section {
                TextEditor(text: $persona.layers.vocabulary)
                    .frame(minHeight: 60)
            } header: {
                Text("Layer 3 — Vocabulary")
            } footer: {
                Text("Words they favor — use naturally, not every sentence.")
            }

            Section {
                TextEditor(text: Binding(
                    get: { persona.layers.negativeConstraints ?? "" },
                    set: { persona.layers.negativeConstraints = $0.isEmpty ? nil : $0 }
                ))
                .frame(minHeight: 50)
            } header: {
                Text("Layer 4 — Constraints")
            } footer: {
                Text("Leave empty to use app defaults: answer substantive questions in voice, no legal/medical advice, PG-13.")
            }

            Section {
                ForEach(Array(persona.layers.fewShots.enumerated()), id: \.offset) { index, _ in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Example \(index + 1)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            if persona.layers.fewShots.count > 1 {
                                Button("Remove", role: .destructive) {
                                    persona.layers.fewShots.remove(at: index)
                                }
                                .font(.caption)
                            }
                        }
                        TextField("User says", text: $persona.layers.fewShots[index].user)
                        TextField("Character replies", text: $persona.layers.fewShots[index].assistant, axis: .vertical)
                            .lineLimit(4...12)
                    }
                }
                Button("Add example") {
                    persona.layers.fewShots.append(FewShot(user: "", assistant: ""))
                }
            } header: {
                Text("Layer 5 — Example exchanges")
            } footer: {
                Text("Include at least one substantive Q&A (science, advice). Substantive examples are sorted first when chatting.")
            }

            Section("Test voice") {
                Button {
                    Task { await runVoiceTests() }
                } label: {
                    if isTesting {
                        HStack {
                            ProgressView()
                            Text("Testing…")
                        }
                    } else {
                        Text("Run 3 test prompts")
                    }
                }
                .disabled(isTesting || persona.name.trimmingCharacters(in: .whitespaces).isEmpty)

                if let testError {
                    Text(testError)
                        .font(.caption)
                        .foregroundStyle(AppTheme.errorText)
                }

                ForEach(testResults) { result in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.prompt)
                            .font(.caption.bold())
                        if let error = result.error {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(AppTheme.errorText)
                        } else {
                            Text(String(result.reply.prefix(400)))
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }
            }

            Section {
                Text(PersonaEngine.assemble(persona: persona))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            } header: {
                Text("System prompt preview")
            } footer: {
                Text("Quality contract and closing checklist are app-wide. Your editable layers are above.")
            }

            if let saveWarning {
                Section {
                    Text(saveWarning)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle(isNew ? "New voice" : "Edit voice")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isBuiltIn {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        showResetConfirm = true
                    }
                }
            } else if !isNew {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Delete", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(persona.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .confirmationDialog(
            "Reset to bundled default?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                if let restored = PersonaStore.resetBuiltIn(id: persona.id, context: modelContext) {
                    persona = restored
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This replaces your edits with the original starter voice from the app bundle.")
        }
        .confirmationDialog(
            "Delete this voice?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                PersonaStore.delete(id: persona.id, context: modelContext)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone. Chats that used this voice will switch to the default voice.")
        }
    }

    private func applyTemplate(_ template: PersonaTemplate) {
        let name = persona.name.trimmingCharacters(in: .whitespaces).isEmpty ? "My Voice" : persona.name
        persona = template.makePersona(named: name, id: persona.id)
    }

    private func runVoiceTests() async {
        isTesting = true
        testError = nil
        testResults = []
        defer { isTesting = false }

        do {
            try await auth.ensureSession()
            testResults = await VoiceTestService.runTests(persona: persona, auth: auth)
        } catch {
            testError = error.localizedDescription
        }
    }

    private func save() {
        saveWarning = validationWarning()
        PersonaStore.save(persona, isBuiltIn: isBuiltIn, context: modelContext)
        dismiss()
    }

    private func validationWarning() -> String? {
        let hasSubstantive = persona.layers.fewShots.contains { shot in
            let user = shot.user.trimmingCharacters(in: .whitespacesAndNewlines)
            return user.count > 40 || user.contains("?")
        }
        if !hasSubstantive && !persona.layers.fewShots.isEmpty {
            return "Tip: add an example where the user asks a real question (science, advice) and the character gives a full answer."
        }
        if persona.layers.fewShots.isEmpty {
            return "Tip: add at least one substantive example so the model learns to answer real questions in this voice."
        }
        return nil
    }
}
