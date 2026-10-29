import Foundation

enum LineState {
    case have
    case swap(String)
    case missing
}

struct PantryStatus {
    var missing: [String] = []
    var swaps: [(missing: String, use: String)] = []
}

/// Compares a recipe's ingredients against what's ticked in the pantry.
enum PantryMatcher {
    /// Keys you count as "have": ticked in the pantry, or marked as a staple.
    static func haveKeys(_ ingredients: [Ingredient]) -> Set<String> {
        Set(ingredients.filter { $0.inPantry || $0.isStaple }.map(\.key))
    }

    static func state(of line: RecipeLine, have: Set<String>) -> LineState {
        guard let ingredient = line.ingredient else { return .have }
        if have.contains(ingredient.key) { return .have }
        if let swap = line.swaps.first(where: { have.contains(IngredientKey.make($0)) }) {
            return .swap(swap)
        }
        return .missing
    }

    static func status(for recipe: Recipe, have: Set<String>) -> PantryStatus {
        var status = PantryStatus()
        for line in recipe.sortedLines {
            let name = line.ingredient?.name ?? ""
            switch state(of: line, have: have) {
            case .have: break
            case .swap(let use): status.swaps.append((name, use))
            case .missing: status.missing.append(name)
            }
        }
        return status
    }
}
