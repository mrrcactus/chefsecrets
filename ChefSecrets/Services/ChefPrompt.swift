import Foundation

/// The prompt you paste into ChatGPT or Claude so the reply comes back in a format `RecipeParser` can read.
enum ChefPrompt {
    static let text = """
    Give me the recipe in exactly this plain-text format (no markdown, no bold, nothing before or after it):

    TITLE: <recipe name>
    SERVINGS: <number>
    MACROS PER SERVING: <calories> kcal | <protein> P | <carbs> C | <fat> F
    INGREDIENTS:
    - <amount> | <ingredient> | swaps: <1-3 substitutes, comma separated>
    STEPS:
    1. <step>

    Rules:
    - Macros are your best per-serving estimate: protein, carbs and fat in grams, calories in kcal.
    - Ingredient names are plain grocery names, singular, no brands, no prep words. Put prep in the amount, e.g. "1, diced".
    - Only add "| swaps: ..." when there is a sensible substitute.
    """
}
