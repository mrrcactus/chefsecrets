import Foundation
import SwiftData

enum RecipeSource: String, CaseIterable, Identifiable {
    case claude, chatGPT, tiktok, me

    var id: String { rawValue }

    var label: String {
        switch self {
        case .claude: "Claude"
        case .chatGPT: "ChatGPT"
        case .tiktok: "TikTok"
        case .me: "Me"
        }
    }

    var symbol: String {
        switch self {
        case .claude, .chatGPT: "sparkles"
        case .tiktok: "play.rectangle.fill"
        case .me: "pencil"
        }
    }
}

enum RecipeCategory: String, CaseIterable, Identifiable {
    case breakfast, meal, dessert, other

    var id: String { rawValue }

    /// Plural, for section headers and filter chips.
    var label: String {
        switch self {
        case .breakfast: "Breakfast"
        case .meal: "Meals"
        case .dessert: "Desserts"
        case .other: "Other"
        }
    }

    var symbol: String {
        switch self {
        case .breakfast: "sun.horizon.fill"
        case .meal: "fork.knife"
        case .dessert: "birthday.cake.fill"
        case .other: "takeoutbag.and.cup.and.straw.fill"
        }
    }

    /// Reads "Breakfast", "Meal", "Meals", "dinner", etc. Anything unrecognised is Other.
    init(text: String) {
        switch text.trimmingCharacters(in: .whitespaces).lowercased() {
        case "breakfast", "brunch": self = .breakfast
        case "meal", "meals", "lunch", "dinner", "main": self = .meal
        case "dessert", "desserts", "sweet", "sweets": self = .dessert
        default: self = .other
        }
    }
}

@Model
final class Recipe {
    var title: String = ""
    var servings: Int = 1
    var steps: [String] = []
    /// Macros are stored per serving.
    var kcal: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var categoryRaw: String = RecipeCategory.other.rawValue
    var sourceRaw: String = RecipeSource.me.rawValue
    var sourceLink: String = ""
    @Attribute(.externalStorage) var photo: Data?
    var dateAdded: Date = Date.now
    /// Set when the recipe was imported from the GitHub recipes folder (reserved for sync).
    var githubPath: String?
    var githubSHA: String?

    @Relationship(deleteRule: .cascade, inverse: \RecipeLine.recipe)
    var lines: [RecipeLine] = []

    init(title: String) {
        self.title = title
    }

    var category: RecipeCategory {
        get { RecipeCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var source: RecipeSource {
        get { RecipeSource(rawValue: sourceRaw) ?? .me }
        set { sourceRaw = newValue.rawValue }
    }

    var sortedLines: [RecipeLine] {
        lines.sorted { $0.order < $1.order }
    }

    /// Grams of protein per 100 kcal — a quick "how protein-dense is this" number.
    var proteinDensity: Double {
        kcal > 0 ? protein / kcal * 100 : 0
    }
}

/// One ingredient line in a recipe: links a recipe to an ingredient with an amount.
@Model
final class RecipeLine {
    var amount: String = ""
    var swaps: [String] = []
    var order: Int = 0
    var recipe: Recipe?
    var ingredient: Ingredient?

    init(amount: String, swaps: [String], order: Int) {
        self.amount = amount
        self.swaps = swaps
        self.order = order
    }
}

/// An ingredient is stored once and shared across recipes, so the pantry filter can match by `key`.
@Model
final class Ingredient {
    @Attribute(.unique) var key: String = ""
    var name: String = ""
    var isStaple: Bool = false
    var inPantry: Bool = false

    @Relationship(inverse: \RecipeLine.ingredient)
    var lines: [RecipeLine] = []

    init(name: String, key: String, isStaple: Bool) {
        self.name = name
        self.key = key
        self.isStaple = isStaple
    }
}
