import SwiftUI

/// Edit who the companion is. The persona is the instruction text Apple's on-device
/// model follows, so whatever you write here is how it acts.
struct SettingsView: View {
    @ObservedObject var store: CompanionStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var persona = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name", text: $name)
                }
                Section {
                    TextEditor(text: $persona)
                        .frame(minHeight: 220)
                } header: {
                    Text("Personality")
                } footer: {
                    Text("Describe how your companion talks and acts. Saving starts a fresh conversation.")
                }
                Section("Brain") {
                    LabeledContent("Using", value: store.brainLabel)
                    if let reason = store.fallbackReason {
                        Text(reason).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section {
                    Button("Reset to default personality", role: .destructive) {
                        store.resetPersona()
                        name = store.name
                        persona = store.persona
                    }
                }
            }
            .navigationTitle("Companion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updatePersona(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                            persona: persona.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                }
            }
            .onAppear {
                name = store.name
                persona = store.persona
            }
        }
    }
}
