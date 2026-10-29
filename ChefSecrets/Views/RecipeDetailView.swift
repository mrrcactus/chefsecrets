import SwiftUI
import SwiftData

struct RecipeDetailView: View {
    let recipe: Recipe

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var ingredients: [Ingredient]
    @State private var editing = false
    @State private var confirmingDelete = false

    var body: some View {
        let have = PantryMatcher.haveKeys(ingredients)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let photo = recipe.photo, let image = UIImage(data: photo) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(recipe.title).font(.largeTitle.bold())
                    HStack {
                        Label(recipe.category.label, systemImage: recipe.category.symbol)
                        Text("·")
                        Label(recipe.source.label, systemImage: recipe.source.symbol)
                        Text("· makes \(recipe.servings)")
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                }

                if let url = URL(string: recipe.sourceLink), !recipe.sourceLink.isEmpty {
                    Link(destination: url) {
                        Label(recipe.source == .tiktok ? "Watch on TikTok" : "Open link",
                              systemImage: recipe.source == .tiktok ? "play.circle.fill" : "link")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                macros
                ingredientsCard(have: have)
                stepsCard
            }
            .padding()
        }
        .background(Color.brandBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { editing = true } label: { Label("Edit", systemImage: "pencil") }
                    Button(role: .destructive) { confirmingDelete = true } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $editing) {
            NavigationStack {
                EditRecipeView(draft: RecipeDraft(recipe: recipe), recipe: recipe) { editing = false }
            }
        }
        .confirmationDialog("Delete \(recipe.title)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                dismiss()
                RecipeStore.delete(recipe, context: context)
            }
        }
    }

    private var macros: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Per serving").font(.caption.bold()).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                MacroTile(value: recipe.kcal, unit: "kcal", label: "Calories", color: .brandDeep)
                MacroTile(value: recipe.protein, unit: "g", label: "Protein", color: .brandPrimary)
                MacroTile(value: recipe.carbs, unit: "g", label: "Carbs", color: .brandSky)
                MacroTile(value: recipe.fat, unit: "g", label: "Fat", color: .brandDeep)
            }
        }
    }

    private func ingredientsCard(have: Set<String>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingredients").font(.title3.bold())
            ForEach(recipe.sortedLines) { line in
                let state = PantryMatcher.state(of: line, have: have)
                HStack(alignment: .top, spacing: 10) {
                    icon(for: state)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            if !line.amount.isEmpty { Text(line.amount).bold() }
                            Text(line.ingredient?.name ?? "")
                        }
                        if case .swap(let use) = state {
                            Text("Using \(use) instead")
                                .font(.caption.bold())
                                .foregroundStyle(Color.brandPrimary)
                        } else if !line.swaps.isEmpty {
                            Text("Swaps: \(line.swaps.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    @ViewBuilder
    private func icon(for state: LineState) -> some View {
        switch state {
        case .have:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.brandPrimary)
        case .swap:
            Image(systemName: "arrow.triangle.swap").foregroundStyle(Color.brandSky)
        case .missing:
            Image(systemName: "circle").foregroundStyle(.orange)
        }
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Steps").font(.title3.bold())
            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Color.brandPrimary, in: Circle())
                    Text(step)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

private struct MacroTile: View {
    let value: Double
    let unit: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(Int(value.rounded()))")
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(unit == "g" ? "\(label) g" : unit)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.brandCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
