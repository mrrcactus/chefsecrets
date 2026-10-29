import Foundation
import SwiftData

enum IngredientKey {
    /// Normalizes a name so "Chicken breasts" and "chicken breast" are the same ingredient.
    static func make(_ name: String) -> String {
        var s = name.lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        if s.hasSuffix("ies"), s.count > 4 {
            s.removeLast(3)
            s += "y"
        } else if s.hasSuffix("oes") {
            s.removeLast(2)
        } else if s.hasSuffix("s"), !s.hasSuffix("ss"), !s.hasSuffix("us"), s.count > 3 {
            s.removeLast()
        }
        return s
    }

    static let defaultStaples: Set<String> = [
        "salt", "pepper", "black pepper", "salt and pepper", "water", "oil", "olive oil",
        "cooking spray", "vegetable oil",
    ]
}

/// Turns drafts into saved recipes, sharing `Ingredient` rows by key.
enum RecipeStore {
    @discardableResult
    static func save(_ draft: RecipeDraft, into existing: Recipe?, context: ModelContext) -> Recipe {
        let recipe = existing ?? Recipe(title: draft.title)
        if existing == nil { context.insert(recipe) }

        recipe.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        recipe.servings = draft.servings
        recipe.kcal = draft.kcal
        recipe.protein = draft.protein
        recipe.carbs = draft.carbs
        recipe.fat = draft.fat
        recipe.source = draft.source
        recipe.sourceLink = draft.sourceLink.trimmingCharacters(in: .whitespacesAndNewlines)
        recipe.photo = draft.photo
        recipe.steps = draft.steps.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

        for old in recipe.lines { context.delete(old) }
        recipe.lines = []

        var cache: [String: Ingredient] = [:]
        for (index, lineDraft) in draft.lines.enumerated() {
            let name = lineDraft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let swaps = lineDraft.swaps.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            let line = RecipeLine(amount: lineDraft.amount.trimmingCharacters(in: .whitespaces), swaps: swaps, order: index)
            context.insert(line)
            line.recipe = recipe
            line.ingredient = ingredient(named: name, context: context, cache: &cache)
            // Swaps get ingredient rows too, so they can be ticked in the pantry.
            for swap in swaps { _ = ingredient(named: swap, context: context, cache: &cache) }
        }

        try? context.save()
        pruneUnused(context: context)
        return recipe
    }

    static func delete(_ recipe: Recipe, context: ModelContext) {
        context.delete(recipe)
        try? context.save()
        pruneUnused(context: context)
    }

    private static func ingredient(named name: String, context: ModelContext, cache: inout [String: Ingredient]) -> Ingredient {
        let key = IngredientKey.make(name)
        if let cached = cache[key] { return cached }

        var descriptor = FetchDescriptor<Ingredient>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        let found = (try? context.fetch(descriptor))?.first
        let result = found ?? {
            let new = Ingredient(name: name, key: key, isStaple: IngredientKey.defaultStaples.contains(key))
            context.insert(new)
            return new
        }()
        cache[key] = result
        return result
    }

    /// Removes ingredients no recipe uses anymore (as a main ingredient or a swap).
    private static func pruneUnused(context: ModelContext) {
        let lines = (try? context.fetch(FetchDescriptor<RecipeLine>())) ?? []
        var used = Set<String>()
        for line in lines {
            if let key = line.ingredient?.key { used.insert(key) }
            for swap in line.swaps { used.insert(IngredientKey.make(swap)) }
        }
        let all = (try? context.fetch(FetchDescriptor<Ingredient>())) ?? []
        for ingredient in all where !used.contains(ingredient.key) {
            context.delete(ingredient)
        }
        try? context.save()
    }
}
