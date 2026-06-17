//
//  Typography.swift
//  Tastecard
//
//  Font system ported from index.css:
//      --font-sans     Inter
//      --font-display  Plus Jakarta Sans
//      --font-mono     JetBrains Mono
//
//  Drop the .ttf files into Resources/Fonts (see that folder's README). Font.custom
//  falls back to the system font automatically if a family is not bundled, so the
//  app always builds and runs. All sizes scale with Dynamic Type via relativeTo.
//

import SwiftUI
import UIKit

enum AppFont {
    enum Family {
        static let display = "PlusJakartaSans"
        static let sans = "Inter"
        static let mono = "JetBrainsMono"
    }

    /// Display (Plus Jakarta Sans) — headings, names, rarity.
    static func display(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo: Font.TextStyle = .body) -> Font {
        custom(Family.display, size: size, weight: weight, relativeTo: relativeTo)
    }

    /// Sans (Inter) — body, chips, buttons.
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo: Font.TextStyle = .body) -> Font {
        custom(Family.sans, size: size, weight: weight, relativeTo: relativeTo)
    }

    /// Mono (JetBrains Mono) — labels, stats, the serial.
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo: Font.TextStyle = .body) -> Font {
        custom(Family.mono, size: size, weight: weight, relativeTo: relativeTo)
    }

    // Maps a logical family + weight to the concrete bundled face name, with a
    // graceful system fallback if the face is missing.
    private static func custom(_ family: String, size: CGFloat, weight: Font.Weight, relativeTo: Font.TextStyle) -> Font {
        let face = faceName(family: family, weight: weight)
        if UIFont(name: face, size: size) != nil {
            return .custom(face, size: size, relativeTo: relativeTo)
        }
        // Fallback: system font at an equivalent weight so layouts never break.
        return .system(size: size, weight: weight, design: family == Family.mono ? .monospaced : .default)
    }

    private static func faceName(family: String, weight: Font.Weight) -> String {
        let suffix: String
        switch weight {
        case .black, .heavy: suffix = family == Family.display ? "ExtraBold" : "Bold"
        case .bold:          suffix = "Bold"
        case .semibold:      suffix = family == Family.mono ? "Medium" : "SemiBold"
        case .medium:        suffix = "Medium"
        default:             suffix = "Regular"
        }
        return "\(family)-\(suffix)"
    }
}
