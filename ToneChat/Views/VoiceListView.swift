import SwiftData
import SwiftUI

struct VoiceListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var auth: AuthService
    @Query(sort: \CustomPersona.createdAt, order: .forward) private var customStored: [CustomPersona]
    @State private var showBuilder = false

    private var personas: [Persona] {
        PersonaStore.allPersonas(from: customStored)
    }

    var body: some View {
        List {
            if personas.isEmpty {
                ContentUnavailableView(
                    "No voices",
                    systemImage: "person.crop.circle.badge.plus",
                    description: Text("Create a voice to get started.")
                )
            } else {
                ForEach(personas) { persona in
                    NavigationLink {
                        PersonaBuilderView(persona: persona, isBuiltIn: persona.isPreset)
                            .environmentObject(auth)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(persona.name)
                                .font(.headline)
                            Text(AppTheme.subtitle(for: persona))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if persona.isPreset {
                            Button("Reset") {
                                _ = PersonaStore.resetBuiltIn(id: persona.id, context: modelContext)
                            }
                            .tint(.orange)
                        } else {
                            Button("Delete", role: .destructive) {
                                PersonaStore.delete(id: persona.id, context: modelContext)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("All voices")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showBuilder = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
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
    }
}
