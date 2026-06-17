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
