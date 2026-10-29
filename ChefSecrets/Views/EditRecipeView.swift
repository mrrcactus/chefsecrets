import SwiftUI
import SwiftData
import PhotosUI

/// Used for new recipes (typed or pasted) and for editing existing ones.
struct EditRecipeView: View {
    let recipe: Recipe?
    let onDone: () -> Void

    @Environment(\.modelContext) private var context
    @AppStorage("lastAISource") private var lastAISource: RecipeSource = .chatGPT
    @State private var draft: RecipeDraft
    @State private var photoItem: PhotosPickerItem?

    init(draft: RecipeDraft, recipe: Recipe?, onDone: @escaping () -> Void) {
        _draft = State(initialValue: draft)
        self.recipe = recipe
        self.onDone = onDone
    }

    var body: some View {
        Form {
            if recipe?.githubPath != nil {
                Section {
                    Label("This recipe syncs from GitHub. If the file changes there, the next sync replaces these edits.",
                          systemImage: "arrow.triangle.2.circlepath")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
            Section {
                TextField("Recipe name", text: $draft.title)
                    .font(.headline)
                Stepper("Servings: \(draft.servings)", value: $draft.servings, in: 1...20)
                Picker("From", selection: $draft.source) {
                    ForEach(RecipeSource.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) }
                }
                TextField("Link (TikTok, website…)", text: $draft.sourceLink)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                PhotosPicker(selection: $photoItem, matching: .images) {
                    HStack {
                        Label(draft.photo == nil ? "Add photo" : "Change photo", systemImage: "photo")
                        Spacer()
                        if draft.photo != nil { RecipeThumbnail(photo: draft.photo, size: 40) }
                    }
                }
            }

            Section("Macros per serving") {
                macroField("Calories", value: $draft.kcal, unit: "kcal")
                macroField("Protein", value: $draft.protein, unit: "g")
                macroField("Carbs", value: $draft.carbs, unit: "g")
                macroField("Fat", value: $draft.fat, unit: "g")
            }

            Section {
                ForEach($draft.lines) { $line in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            TextField("Amount", text: $line.amount)
                                .frame(width: 96)
                                .bold()
                            TextField("Ingredient", text: $line.name)
                        }
                        TextField("Swaps, comma separated", text: $line.swaps)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { draft.lines.remove(atOffsets: $0) }
                .onMove { draft.lines.move(fromOffsets: $0, toOffset: $1) }
                Button {
                    draft.lines.append(LineDraft())
                } label: {
                    Label("Add ingredient", systemImage: "plus")
                }
            } header: {
                Text("Ingredients")
            } footer: {
                Text("Swaps are substitutes. If you have a swap ticked in Pantry, the recipe counts it as covered.")
            }

            Section("Steps") {
                ForEach($draft.steps) { $step in
                    TextField("Step", text: $step.text, axis: .vertical)
                }
                .onDelete { draft.steps.remove(atOffsets: $0) }
                .onMove { draft.steps.move(fromOffsets: $0, toOffset: $1) }
                Button {
                    draft.steps.append(StepDraft())
                } label: {
                    Label("Add step", systemImage: "plus")
                }
            }
        }
        .navigationTitle(recipe == nil ? "New recipe" : "Edit recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { onDone() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .bold()
                    .disabled(draft.title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onChange(of: photoItem) {
            Task {
                if let data = try? await photoItem?.loadTransferable(type: Data.self) {
                    draft.photo = ImageResize.jpeg(from: data) ?? data
                }
            }
        }
    }

    private func macroField(_ label: String, value: Binding<Double>, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .bold()
            Text(unit).foregroundStyle(.secondary).frame(width: 34, alignment: .leading)
        }
    }

    private func save() {
        if draft.source == .claude || draft.source == .chatGPT { lastAISource = draft.source }
        RecipeStore.save(draft, into: recipe, context: context)
        onDone()
    }
}
