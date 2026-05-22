import SwiftUI

struct PersonaPickerSheet: View {
    let personas: [Persona]
    @Binding var selectedPersonaId: String
    var onEditPersona: ((Persona) -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Voices") {
                    ForEach(personas) { persona in
                        HStack {
                            Button {
                                selectedPersonaId = persona.id
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(persona.name)
                                            .font(.headline)
                                        Text(AppTheme.subtitle(for: persona))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if persona.id == selectedPersonaId {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)

                            if let onEditPersona {
                                Button {
                                    onEditPersona(persona)
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Edit \(persona.name)")
                            }
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
}
