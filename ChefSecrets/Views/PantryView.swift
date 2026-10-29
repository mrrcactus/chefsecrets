import SwiftUI
import SwiftData

struct PantryView: View {
    @Query(sort: \Ingredient.name) private var ingredients: [Ingredient]
    @State private var search = ""

    private var matching: [Ingredient] {
        search.isEmpty ? ingredients : ingredients.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Tick what's in your kitchen. Staples like salt and oil always count as \"have\". Swipe left on a row to change whether it's a staple.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                section("In your recipes", matching.filter { !$0.isStaple && !$0.lines.isEmpty })
                section("Swap options", matching.filter { !$0.isStaple && $0.lines.isEmpty })
                section("Staples (always counted)", matching.filter(\.isStaple))
            }
            .navigationTitle("Pantry")
            .searchable(text: $search, prompt: "Search ingredients")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear ticks") {
                        for ingredient in ingredients { ingredient.inPantry = false }
                    }
                    .disabled(!ingredients.contains(where: \.inPantry))
                }
            }
            .overlay {
                if ingredients.isEmpty {
                    ContentUnavailableView("No ingredients yet",
                                           systemImage: "basket",
                                           description: Text("Ingredients show up here once you add recipes."))
                }
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ items: [Ingredient]) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(items) { ingredient in
                    PantryRow(ingredient: ingredient)
                }
            }
        }
    }
}

private struct PantryRow: View {
    @Bindable var ingredient: Ingredient

    var body: some View {
        Button {
            ingredient.inPantry.toggle()
        } label: {
            HStack {
                Image(systemName: ingredient.inPantry || ingredient.isStaple ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(ingredient.inPantry || ingredient.isStaple ? Color.brandPrimary : .secondary)
                Text(ingredient.name.capitalized)
                    .foregroundStyle(.primary)
                Spacer()
                if !ingredient.lines.isEmpty {
                    Text("\(Set(ingredient.lines.compactMap { $0.recipe?.id }).count)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .disabled(ingredient.isStaple)
        .swipeActions {
            Button(ingredient.isStaple ? "Not a staple" : "Staple") {
                ingredient.isStaple.toggle()
            }
            .tint(.brandDeep)
        }
    }
}
