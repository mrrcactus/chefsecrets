import SwiftUI
import SwiftData

enum RecipeSort: String, CaseIterable, Identifiable {
    case newest, protein, calories, density

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newest: "Newest"
        case .protein: "Most protein"
        case .calories: "Fewest calories"
        case .density: "Protein per calorie"
        }
    }
}

private struct ScoredRecipe: Identifiable {
    let recipe: Recipe
    let status: PantryStatus
    var id: PersistentIdentifier { recipe.persistentModelID }
}

struct RecipeListView: View {
    @Query(sort: \Recipe.dateAdded, order: .reverse) private var recipes: [Recipe]
    @Query private var ingredients: [Ingredient]

    @State private var search = ""
    @AppStorage("recipeSort") private var sort: RecipeSort = .newest
    @AppStorage("filterByPantry") private var filterByPantry = false
    @AppStorage("maxMissing") private var maxMissing = 2
    /// Empty string means "All".
    @AppStorage("categoryFilter") private var categoryFilter = ""
    @State private var showingPaste = false
    @State private var showingNew = false
    @State private var syncing = false
    @State private var syncMessage: String?
    @Environment(\.modelContext) private var context

    private var visible: [Recipe] {
        let matches = recipes.filter {
            (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search))
                && (categoryFilter.isEmpty || $0.categoryRaw == categoryFilter)
        }
        switch sort {
        case .newest: return matches
        case .protein: return matches.sorted { $0.protein > $1.protein }
        case .calories: return matches.sorted { $0.kcal < $1.kcal }
        case .density: return matches.sorted { $0.proteinDensity > $1.proteinDensity }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    categoryChips
                    filterBar
                    if recipes.isEmpty {
                        emptyState
                    } else if filterByPantry {
                        pantryGroups
                    } else {
                        categoryGroups
                    }
                }
                .padding()
            }
            .background(Color.brandBackground)
            .navigationTitle("ChefSecrets")
            .navigationDestination(for: Recipe.self) { RecipeDetailView(recipe: $0) }
            .searchable(text: $search, prompt: "Search recipes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Sort", selection: $sort) {
                            ForEach(RecipeSort.allCases) { Text($0.label).tag($0) }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showingPaste = true } label: {
                            Label("Paste recipe", systemImage: "doc.on.clipboard")
                        }
                        Button { showingNew = true } label: {
                            Label("Type it in", systemImage: "square.and.pencil")
                        }
                        Divider()
                        Button { Task { await sync() } } label: {
                            Label("Sync from GitHub", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .disabled(syncing)
                    } label: {
                        Image(systemName: "plus.circle.fill").font(.title3)
                    }
                }
            }
            .refreshable { await sync() }
            // Quiet sync on launch; failures (e.g. offline) only show when you sync by hand.
            .task { _ = try? await GitHubSync.run(context: context) }
            .alert("GitHub sync", isPresented: Binding(
                get: { syncMessage != nil },
                set: { if !$0 { syncMessage = nil } }
            )) {
                Button("OK") {}
            } message: {
                Text(syncMessage ?? "")
            }
            .sheet(isPresented: $showingPaste) { PasteRecipeView() }
            .sheet(isPresented: $showingNew) {
                NavigationStack {
                    EditRecipeView(draft: RecipeDraft(), recipe: nil) { showingNew = false }
                }
            }
        }
    }

    private func sync() async {
        syncing = true
        defer { syncing = false }
        do {
            syncMessage = try await GitHubSync.run(context: context).summary
        } catch {
            syncMessage = "Couldn't sync: \(error.localizedDescription)"
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", symbol: "square.grid.2x2.fill", value: "")
                ForEach(RecipeCategory.allCases) { chip($0.label, symbol: $0.symbol, value: $0.rawValue) }
            }
        }
    }

    private func chip(_ title: String, symbol: String, value: String) -> some View {
        let selected = categoryFilter == value
        return Button {
            withAnimation { categoryFilter = value }
        } label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selected ? Color.brandPrimary : Color.brandCard, in: Capsule())
                .foregroundStyle(selected ? Color.white : Color.brandDeep)
        }
        .buttonStyle(.plain)
    }

    /// Breakfast, Meals, Desserts, Other — each as its own block, skipping empty ones.
    @ViewBuilder
    private var categoryGroups: some View {
        let shown = visible
        if shown.isEmpty {
            Text("No recipes here yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
        ForEach(RecipeCategory.allCases) { category in
            let group = shown.filter { $0.category == category }
            if !group.isEmpty {
                Label(category.label, systemImage: category.symbol)
                    .font(.title3.bold())
                    .foregroundStyle(Color.brandDeep)
                    .padding(.top, 6)
                ForEach(group) { recipe in
                    NavigationLink(value: recipe) { RecipeCard(recipe: recipe) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $filterByPantry.animation()) {
                Label("What I have", systemImage: "basket.fill").font(.subheadline.bold())
            }
            if filterByPantry {
                Stepper(value: $maxMissing, in: 0...5) {
                    Text(maxMissing == 0 ? "Only what I can make now" : "Show recipes missing up to \(maxMissing)")
                        .font(.subheadline)
                }
            }
        }
        .cardStyle()
    }

    @ViewBuilder
    private var pantryGroups: some View {
        let have = PantryMatcher.haveKeys(ingredients)
        let shown = visible
            .map { ScoredRecipe(recipe: $0, status: PantryMatcher.status(for: $0, have: have)) }
            .filter { $0.status.missing.count <= maxMissing }

        if shown.isEmpty {
            Text("Nothing matches yet. Tick more ingredients in Pantry, or raise the limit above.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
        ForEach(0...maxMissing, id: \.self) { count in
            let group = shown.filter { $0.status.missing.count == count }
            if !group.isEmpty {
                Text(count == 0 ? "Can make now" : "Missing \(count)")
                    .font(.title3.bold())
                    .foregroundStyle(Color.brandDeep)
                    .padding(.top, 6)
                ForEach(group) { item in
                    NavigationLink(value: item.recipe) { RecipeCard(recipe: item.recipe, status: item.status) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.brandPrimary)
            Text("No recipes yet").font(.title3.bold())
            Text("Pull down to sync from GitHub, or tap + to paste a recipe from ChatGPT or Claude.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
