//
//  DropletIcon.swift
//  Tastecard
//
//  Recreates "the drop" outline SVG from App.tsx (the theme randomiser glyph). Drawn in
//  a 24x24 space and scaled to fit; stroked with the current foreground color.
//

import SwiftUI

struct DropletIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24.0
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }

        var path = Path()
        // Teardrop: pointed at top (12,4), rounded bottom around (12,15) r6.
        path.move(to: p(12, 4))
        path.addQuadCurve(to: p(18, 15), control: p(18, 8.5))
        path.addArc(center: p(12, 15), radius: 6 * s,
                    startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        path.addQuadCurve(to: p(12, 4), control: p(6, 8.5))
        path.closeSubpath()

        // Inner glisten: short inward curve near the lower-left.
        path.move(to: p(10, 16))
        path.addQuadCurve(to: p(10, 12.5), control: p(8.4, 14.3))
        return path
    }
}

struct DropButton: View {
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            DropletIcon()
                .stroke(color, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                .frame(width: 28, height: 28)
                .padding(2)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Randomise color theme")
    }
}
