//
//  Glass.swift
//  Tastecard
//
//  Glassmorphism system. The web card is `backdrop-blur-3xl` + a translucent
//  fill + a white border (rounded-[40px], shadow-xl). The native equivalent is a
//  Material (which blurs what's behind it) under an explicit tint fill, with a
//  hairline white border. Fill/border colors are supplied by the caller because
//  they are theme- and brightness-adaptive (see CardView / SnapshotView).
//

import SwiftUI
import UIKit

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 40
    var fill: Color
    var border: Color
    var material: Material = .ultraThinMaterial
    var shadow: Bool = true

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .background {
                shape
                    .fill(material)
                    .overlay(shape.fill(fill))
            }
            .overlay {
                shape.strokeBorder(border, lineWidth: 1)
            }
            .modifier(ConditionalShadow(enabled: shadow))
    }
}

private struct ConditionalShadow: ViewModifier {
    let enabled: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if enabled {
            // Approximates Tailwind shadow-xl.
            content.shadow(color: .black.opacity(0.18), radius: 22, x: 0, y: 12)
        } else {
            content
        }
    }
}

extension View {
    /// The main glass card surface.
    func glassCard(cornerRadius: CGFloat = 40,
                   fill: Color,
                   border: Color,
                   material: Material = .ultraThinMaterial,
                   shadow: Bool = true) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, fill: fill, border: border, material: material, shadow: shadow))
    }

    /// A lighter glass pill used for chips and inline buttons (`backdrop-blur-md`).
    func glassPill(cornerRadius: CGFloat,
                   fill: Color,
                   border: Color) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background {
                shape.fill(.ultraThinMaterial).overlay(shape.fill(fill))
            }
            .overlay { shape.strokeBorder(border, lineWidth: 1) }
            .clipShape(shape)
    }
}

/// The card's glass surface. With a custom background it renders TRUE glass: a blurred,
/// position-aligned slice of the wallpaper shows through the card (like iOS Control
/// Centre), with only a light tint — instead of `Material`, which over a separate
/// background layer frosts to a flat grey. Without a custom background it uses the
/// theme's Material glass.
struct CardGlass: ViewModifier {
    var cornerRadius: CGFloat = 40
    let customBackground: UIImage?
    let screen: CGSize
    let fill: Color
    let border: Color
    let themeGlassFill: Color

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .background {
                if let bg = customBackground {
                    GeometryReader { g in
                        let frame = g.frame(in: .global)
                        // Draw the wallpaper full-screen, offset so the slice inside the
                        // card lines up with what's actually behind it, then blur + tint.
                        Image(uiImage: bg)
                            .resizable()
                            .scaledToFill()
                            .frame(width: screen.width, height: screen.height)
                            .offset(x: -frame.minX, y: -frame.minY)
                            .blur(radius: 24)
                            .overlay(fill)
                    }
                    .clipShape(shape)
                } else {
                    shape.fill(.ultraThinMaterial).overlay(shape.fill(themeGlassFill))
                }
            }
            .overlay(shape.strokeBorder(border, lineWidth: 1))
            .shadow(color: .black.opacity(0.18), radius: 22, x: 0, y: 12)
    }
}

extension View {
    func cardGlass(cornerRadius: CGFloat = 40,
                   customBackground: UIImage?,
                   screen: CGSize,
                   fill: Color,
                   border: Color,
                   themeGlassFill: Color) -> some View {
        modifier(CardGlass(cornerRadius: cornerRadius, customBackground: customBackground,
                           screen: screen, fill: fill, border: border, themeGlassFill: themeGlassFill))
    }
}

/// Standard vignette overlay used over photos (from-black/85 via-black/25 to-transparent).
struct PhotoVignette: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.85), location: 0.0),
                .init(color: .black.opacity(0.25), location: 0.45),
                .init(color: .clear, location: 1.0),
            ],
            startPoint: .bottom,
            endPoint: .top
        )
        .allowsHitTesting(false)
    }
}
