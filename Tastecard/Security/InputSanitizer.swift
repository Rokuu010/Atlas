//
//  InputSanitizer.swift
//  Tastecard
//
//  The only free-text input in the app is the editable display name (§9). We trim,
//  cap length, strip control/zero-width characters, and provide a filename-safe form
//  (keeping the repo's `replace(/[^a-z0-9]/g,'_')` behaviour for the export filename).
//  SwiftUI escapes rendered text by default; there is no HTML/WKWebView injection path.
//

import Foundation

enum InputSanitizer {
    static let maxDisplayNameLength = 40
    static let maxAboutMeLength = 160

    /// Sanitises a user-entered display name:
    ///   - strips control characters and zero-width / bidi formatting characters
    ///   - collapses internal whitespace runs to single spaces
    ///   - trims, then caps to `maxDisplayNameLength` characters
    static func displayName(_ raw: String) -> String {
        var scalars = String.UnicodeScalarView()
        for s in raw.unicodeScalars {
            if isDisallowed(s) { continue }
            scalars.append(s)
        }
        var cleaned = String(scalars)
        // Collapse whitespace.
        cleaned = cleaned.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count > maxDisplayNameLength {
            cleaned = String(cleaned.prefix(maxDisplayNameLength))
        }
        return cleaned
    }

    /// Returns a non-empty display name, falling back to a safe default.
    static func displayNameOrDefault(_ raw: String, default fallback: String = "My Tastecard") -> String {
        let s = displayName(raw)
        return s.isEmpty ? fallback : s
    }

    /// Sanitises the free-text "About me": same control/zero-width stripping and whitespace
    /// collapse as the display name, but a longer cap. May be empty (the card hides it).
    static func aboutMe(_ raw: String) -> String {
        var scalars = String.UnicodeScalarView()
        for s in raw.unicodeScalars where !isDisallowed(s) { scalars.append(s) }
        var cleaned = String(scalars)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count > maxAboutMeLength { cleaned = String(cleaned.prefix(maxAboutMeLength)) }
        return cleaned
    }

    /// Filename-safe slug for the exported PNG (matches the web mockup's rule).
    static func filenameSlug(_ raw: String) -> String {
        let lowered = displayName(raw).lowercased()
        let mapped = lowered.unicodeScalars.map { scalar -> Character in
            let isAllowed = (scalar >= "a" && scalar <= "z") || (scalar >= "0" && scalar <= "9")
            return isAllowed ? Character(scalar) : "_"
        }
        var slug = String(mapped)
        while slug.contains("__") { slug = slug.replacingOccurrences(of: "__", with: "_") }
        slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return slug.isEmpty ? "tastecard" : slug
    }

    private static func isDisallowed(_ s: Unicode.Scalar) -> Bool {
        // Control characters (C0/C1) except we've already handled whitespace separately.
        if s.value < 0x20 || (s.value >= 0x7F && s.value <= 0x9F) { return true }
        // Zero-width and bidi/formatting characters often used for spoofing.
        let formatting: Set<UInt32> = [
            0x200B, 0x200C, 0x200D, 0x200E, 0x200F, 0xFEFF,
            0x202A, 0x202B, 0x202C, 0x202D, 0x202E,
            0x2066, 0x2067, 0x2068, 0x2069,
        ]
        return formatting.contains(s.value)
    }
}
