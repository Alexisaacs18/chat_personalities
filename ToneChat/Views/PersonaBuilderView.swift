import SwiftData
import SwiftUI

struct PersonaBuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var persona: Persona
    let isNew: Bool

    init(persona: Persona? = nil) {
        if let persona {
            _persona = State(initialValue: persona)
            isNew = false
        } else {
            _persona = State(initialValue: Persona(
                id: UUID().uuidString,
                name: "My Voice",
                isPreset: false,
                layers: PersonaLayers(
                    coreIdentity: "",
                    speechPatterns: "",
                    vocabulary: "",
                    negativeConstraints: nil,
                    fewShots: []
                ),
                intensities: .full
            ))
            isNew = true
        }
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Voice name", text: $persona.name)
            }

            Section("Layer 1 — Core identity") {
                TextEditor(text: $persona.layers.coreIdentity)
                    .frame(minHeight: 80)
            }

            Section("Layer 2 — Speech patterns") {
                TextEditor(text: $persona.layers.speechPatterns)
                    .frame(minHeight: 80)
            }

            Section("Layer 3 — Vocabulary") {
                TextEditor(text: $persona.layers.vocabulary)
                    .frame(minHeight: 60)
            }

            Section("Constraints (optional)") {
                TextEditor(text: Binding(
                    get: { persona.layers.negativeConstraints ?? "" },
                    set: { persona.layers.negativeConstraints = $0.isEmpty ? nil : $0 }
                ))
                .frame(minHeight: 50)
            }

            PersonaIntensityView(intensities: $persona.intensities)

            Section("Layer 4 — Examples") {
                ForEach(Array(persona.layers.fewShots.enumerated()), id: \.offset) { index, _ in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("User says", text: $persona.layers.fewShots[index].user)
                        TextField("Character replies", text: $persona.layers.fewShots[index].assistant, axis: .vertical)
                    }
                }
                Button("Add example") {
                    persona.layers.fewShots.append(FewShot(user: "", assistant: ""))
                }
            }

            Section("Preview") {
                Text(PersonaEngine.assemble(persona: persona))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(isNew ? "New voice" : "Edit voice")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(persona.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func save() {
        let descriptor = FetchDescriptor<CustomPersona>(
            predicate: #Predicate { $0.id == persona.id }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.update(from: persona)
        } else {
            modelContext.insert(CustomPersona(from: persona))
        }
        try? modelContext.save()
        dismiss()
    }
}
