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
