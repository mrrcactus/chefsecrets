import SwiftUI
import SwiftData

@main
struct ChefSecretsApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Recipe.self, RecipeLine.self, Ingredient.self)
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .tint(.brandPrimary)
        }
        .modelContainer(container)
    }
}
