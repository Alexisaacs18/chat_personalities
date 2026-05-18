import SwiftData
import SwiftUI

struct CustomPersonaListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomPersona.createdAt, order: .reverse) private var stored: [CustomPersona]
    @State private var showBuilder = false

    var body: some View {
        List {
            if stored.isEmpty {
                ContentUnavailableView(
                    "No custom voices",
                    systemImage: "person.crop.circle.badge.plus",
                    description: Text("Duplicate a preset or create a new voice.")
                )
            } else {
                ForEach(stored, id: \.id) { item in
                    NavigationLink {
                        PersonaBuilderView(persona: item.toPersona())
                    } label: {
                        Text(item.name)
                    }
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("Custom voices")
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
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showBuilder = false }
                        }
                    }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(stored[index])
        }
        try? modelContext.save()
    }
}
