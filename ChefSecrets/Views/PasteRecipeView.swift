import SwiftUI

struct PasteRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("lastAISource") private var lastSource: RecipeSource = .chatGPT

    @State private var text = ""
    @State private var copied = false
    @State private var parsed = RecipeDraft()
    @State private var showingEditor = false
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Send this prompt to ChatGPT or Claude along with your request, or with a TikTok caption you want turned into a recipe.")
                        .font(.subheadline)
                    Button {
                        UIPasteboard.general.string = ChefPrompt.text
                        copied = true
                    } label: {
                        Label(copied ? "Copied!" : "Copy ChefSecrets prompt",
                              systemImage: copied ? "checkmark" : "doc.on.doc")
                            .bold()
                    }
                    DisclosureGroup("See the prompt") {
                        Text(ChefPrompt.text).font(.caption.monospaced())
                    }
                } header: {
                    Text("1 · Get the recipe")
                }

                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 220)
                        .font(.callout.monospaced())
                    Button {
                        text = UIPasteboard.general.string ?? ""
                    } label: {
                        Label("Paste from clipboard", systemImage: "doc.on.clipboard")
                    }
                } header: {
                    Text("2 · Paste the reply")
                }

                if let problem {
                    Section {
                        Label(problem, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Paste recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Read it") { read() }
                        .bold()
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationDestination(isPresented: $showingEditor) {
                EditRecipeView(draft: parsed, recipe: nil) { dismiss() }
            }
        }
    }

    private func read() {
        var draft = RecipeParser.parse(text)
        guard !draft.title.isEmpty || !draft.lines.isEmpty else {
            problem = "Couldn't find a TITLE or INGREDIENTS section. Make sure the reply used the ChefSecrets prompt."
            return
        }
        if draft.source != .tiktok { draft.source = lastSource }
        problem = nil
        parsed = draft
        showingEditor = true
    }
}
