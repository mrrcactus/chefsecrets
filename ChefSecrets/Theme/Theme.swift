import SwiftUI

extension Color {
    static let brandPrimary = Color("BrandPrimary")
    static let brandDeep = Color("BrandDeep")
    static let brandSky = Color("BrandSky")
    static let brandBackground = Color("BrandBackground")
    static let brandCard = Color("BrandCard")
}

extension ShapeStyle where Self == Color {
    static var brandPrimary: Color { .brandPrimary }
    static var brandDeep: Color { .brandDeep }
    static var brandSky: Color { .brandSky }
    static var brandBackground: Color { .brandBackground }
    static var brandCard: Color { .brandCard }
}

/// Card styling shared across dashboard tiles and list-like surfaces.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color.brandCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.brandDeep.opacity(0.08), radius: 6, y: 2)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardBackground())
    }
}
