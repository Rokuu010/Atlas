//
//  AppTheme.swift
//  Tastecard
//
//  The 16 curated color themes, ported verbatim from APP_THEMES in the React
//  source (App.tsx). Hex values, glass tints and border opacities are exact.
//  Tailwind classes are translated to native parameters:
//      bg-white/10   -> glassTint = .white, glassTintOpacity = 0.10
//      bg-black/20   -> glassTint = .black, glassTintOpacity = 0.20
//      border-white/25 -> glassBorderOpacity = 0.25
//

import SwiftUI

/// A single page theme: a flat background color plus the glass parameters used
/// by the card. `text` is the on-background foreground color.
struct AppTheme: Equatable, Identifiable {
    let id: Int                  // index into AppTheme.all — "the drop" randomises this
    let name: String
    let background: Color
    let text: Color
    let glassTint: Color         // white or black, matching the Tailwind fill
    let glassTintOpacity: Double
    let glassBorderOpacity: Double // border is always white in the source

    var glassFill: Color { glassTint.opacity(glassTintOpacity) }
    var glassBorder: Color { Color.white.opacity(glassBorderOpacity) }
}

extension AppTheme {
    /// The canonical ordered list. Order and values match App.tsx exactly.
    static let all: [AppTheme] = [
        AppTheme(id: 0,  name: "Cream",            background: Color(hex: 0xF3E5C3), text: Color(hex: 0x0C1519), glassTint: .white, glassTintOpacity: 0.10, glassBorderOpacity: 0.25),
        AppTheme(id: 1,  name: "China Rose",       background: Color(hex: 0xA24C61), text: Color(hex: 0xFDF9F6), glassTint: .white, glassTintOpacity: 0.05, glassBorderOpacity: 0.15),
        AppTheme(id: 2,  name: "Kobi",             background: Color(hex: 0xE2A9C0), text: Color(hex: 0x411528), glassTint: .white, glassTintOpacity: 0.10, glassBorderOpacity: 0.20),
        AppTheme(id: 3,  name: "Queen Pink",       background: Color(hex: 0xE1C9D5), text: Color(hex: 0x411528), glassTint: .white, glassTintOpacity: 0.10, glassBorderOpacity: 0.20),
        AppTheme(id: 4,  name: "Chocolate Kisses", background: Color(hex: 0x411528), text: Color(hex: 0xFFEFF5), glassTint: .white, glassTintOpacity: 0.05, glassBorderOpacity: 0.10),
        AppTheme(id: 5,  name: "Persian Plum",     background: Color(hex: 0x710C21), text: Color(hex: 0xFDF0F3), glassTint: .black, glassTintOpacity: 0.20, glassBorderOpacity: 0.15),
        AppTheme(id: 6,  name: "Jacarta",          background: Color(hex: 0x3F2A52), text: Color(hex: 0xF5EFFF), glassTint: .white, glassTintOpacity: 0.05, glassBorderOpacity: 0.10),
        AppTheme(id: 7,  name: "Dark Blue-Gray",   background: Color(hex: 0x75619D), text: Color(hex: 0xFFFFFF), glassTint: .white, glassTintOpacity: 0.05, glassBorderOpacity: 0.15),
        AppTheme(id: 8,  name: "Wisteria",         background: Color(hex: 0xBEAEDB), text: Color(hex: 0x3F2A52), glassTint: .white, glassTintOpacity: 0.10, glassBorderOpacity: 0.20),
        AppTheme(id: 9,  name: "Bright Gray",      background: Color(hex: 0xE6EFF7), text: Color(hex: 0x3A2D34), glassTint: .white, glassTintOpacity: 0.15, glassBorderOpacity: 0.30),
        AppTheme(id: 10, name: "Black Coffee",     background: Color(hex: 0x3A2D34), text: Color(hex: 0xF0EBF2), glassTint: .white, glassTintOpacity: 0.05, glassBorderOpacity: 0.10),
        AppTheme(id: 11, name: "Cadet Grey",       background: Color(hex: 0x959BB5), text: Color(hex: 0x0A1123), glassTint: .white, glassTintOpacity: 0.10, glassBorderOpacity: 0.20),
        AppTheme(id: 12, name: "Chinese Black",    background: Color(hex: 0x0A1123), text: Color(hex: 0xE6EFF7), glassTint: .white, glassTintOpacity: 0.05, glassBorderOpacity: 0.10),
        AppTheme(id: 13, name: "American Blue",    background: Color(hex: 0x3A3E6C), text: Color(hex: 0xE6EFF7), glassTint: .white, glassTintOpacity: 0.05, glassBorderOpacity: 0.10),
        AppTheme(id: 14, name: "Ube",              background: Color(hex: 0x8387C3), text: Color(hex: 0x0A1123), glassTint: .white, glassTintOpacity: 0.10, glassBorderOpacity: 0.20),
        AppTheme(id: 15, name: "Cool Grey",        background: Color(hex: 0x8A8CAC), text: Color(hex: 0x0A1123), glassTint: .white, glassTintOpacity: 0.10, glassBorderOpacity: 0.20),
    ]

    static func theme(at index: Int) -> AppTheme {
        all[((index % all.count) + all.count) % all.count]
    }

    /// "The drop": pick a random theme index that is never the current one.
    static func nextDropIndex(current: Int) -> Int {
        guard all.count > 1 else { return current }
        var next = current
        while next == current { next = Int.random(in: 0..<all.count) }
        return next
    }
}

extension Color {
    /// Hex initialiser, e.g. `Color(hex: 0xF3E5C3)`.
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
