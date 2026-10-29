import SwiftUI

/// "540 kcal  45P  52C  15F" — shown on every recipe card.
struct MacroStrip: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 6) {
            Text("\(Int(recipe.kcal.rounded())) kcal")
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
            MacroPill(letter: "P", grams: recipe.protein, color: .brandPrimary)
            MacroPill(letter: "C", grams: recipe.carbs, color: .brandSky)
            MacroPill(letter: "F", grams: recipe.fat, color: .brandDeep)
        }
    }
}

struct MacroPill: View {
    let letter: String
    let grams: Double
    let color: Color

    var body: some View {
        Text("\(Int(grams.rounded()))\(letter)")
            .font(.caption.bold())
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

struct RecipeThumbnail: View {
    let photo: Data?
    var size: CGFloat = 64

    var body: some View {
        Group {
            if let photo, let image = UIImage(data: photo) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "fork.knife")
                    .font(.title2.bold())
                    .foregroundStyle(Color.brandPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.brandSky.opacity(0.18))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct RecipeCard: View {
    let recipe: Recipe
    /// Only passed when the "What I have" filter is on.
    var status: PantryStatus?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RecipeThumbnail(photo: recipe.photo)
            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.title)
                    .font(.headline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                MacroStrip(recipe: recipe)
                if let status {
                    if !status.missing.isEmpty {
                        Label("Need: \(status.missing.joined(separator: ", "))", systemImage: "cart")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                    }
                    ForEach(Array(status.swaps.enumerated()), id: \.offset) { _, swap in
                        Label("Swap \(swap.missing) → \(swap.use)", systemImage: "arrow.triangle.swap")
                            .font(.caption.bold())
                            .foregroundStyle(Color.brandPrimary)
                    }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.bold())
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .cardStyle()
    }
}
