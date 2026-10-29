import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            RecipeListView()
                .tabItem { Label("Recipes", systemImage: "book.fill") }
            PantryView()
                .tabItem { Label("Pantry", systemImage: "basket.fill") }
        }
    }
}
