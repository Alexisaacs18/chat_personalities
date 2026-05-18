import SwiftUI

struct PersonaPickerSheet: View {
    let presets: [Persona]
    let customPersonas: [Persona]
    @Binding var selectedPersonaId: String
    var onDuplicatePreset: ((Persona) -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Presets") {
                    ForEach(presets) { persona in
                        personaRow(persona)
                    }
                }
                if !customPersonas.isEmpty {
                    Section("Custom") {
                        ForEach(customPersonas) { persona in
                            personaRow(persona)
                        }
                    }
                }
            }
            .navigationTitle("Choose voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func personaRow(_ persona: Persona) -> some View {
        HStack {
            Button {
                selectedPersonaId = persona.id
                dismiss()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(persona.name)
                            .font(.headline)
                        if persona.isPreset {
                            Text("Preset character")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if persona.id == selectedPersonaId {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .foregroundStyle(.primary)

            if persona.isPreset, let onDuplicatePreset {
                Button {
                    var copy = persona
                    copy.id = UUID().uuidString
                    copy.name = "\(persona.name) Copy"
                    copy.isPreset = false
                    onDuplicatePreset(copy)
                    selectedPersonaId = copy.id
                    dismiss()
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Duplicate and customize")
            }
        }
    }
}
