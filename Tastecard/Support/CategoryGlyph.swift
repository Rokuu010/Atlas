//
//  CategoryGlyph.swift
//  Tastecard
//
//  Designed placeholder for a theme when no suitable photo is available (e.g. every
//  candidate was filtered out as a private screenshot/document). Maps a category id to an
//  SF Symbol + a deterministic gradient so the tile looks intentional, never broken.
//

import SwiftUI

enum CategoryGlyph {
    /// SF Symbol for a category, chosen by keyword with a sensible default.
    static func symbol(for categoryId: String) -> String {
        let id = categoryId
        func has(_ keys: String...) -> Bool { keys.contains { id.contains($0) } }
        switch true {
        case has("coffee", "matcha", "boba", "tea"): return "cup.and.saucer.fill"
        case has("run", "marathon"): return "figure.run"
        case has("gym", "iron"): return "dumbbell.fill"
        case has("yoga", "flow"): return "figure.yoga"
        case has("pitch", "football", "hoop", "court", "tee_time", "cricket", "net_result", "strike", "baize", "bullseye"): return "sportscourt.fill"
        case has("cycl", "two_wheels"): return "bicycle"
        case has("swim", "surf", "sea_legs", "salt"): return "water.waves"
        case has("powder", "fresh_ice"): return "snowflake"
        case has("climb", "summit", "trail", "wild", "desert", "waterfall", "cave"): return "mountain.2.fill"
        case has("car", "engine", "throttle", "off_the_grid", "apex"): return "car.fill"
        case has("plane", "wheels_up"): return "airplane"
        case has("steam_engine"): return "tram.fill"
        case has("boat", "sea_legs"): return "sailboat.fill"
        case has("book", "chapter", "inked_pages", "study", "note", "diary"): return "book.fill"
        case has("player_one", "arcade", "battlestation"): return "gamecontroller.fill"
        case has("tech", "drone", "maker_mode", "viewfinder", "lens"): return "camera.fill"
        case has("paws", "good_boy", "feathered", "tank", "scales", "farmyard", "safari", "saddle"): return "pawprint.fill"
        case has("eat", "burger", "pizza", "sushi", "ramen", "taco", "steak", "bird_and_sauce", "brunch", "street_eats", "home_chef", "spice", "cheese", "fire_and_smoke"): return "fork.knife"
        case has("doughnut", "glaze", "ice_cream", "sweet", "bake", "make_a_wish"): return "birthday.cake.fill"
        case has("wine", "cocktail", "last_round"): return "wineglass.fill"
        case has("guitar", "keys", "beat", "decks", "vinyl", "mic", "front_row", "crowd_surfer", "string"): return "music.note"
        case has("paint", "brush", "sketch", "clay", "yarn", "puzzle", "lego", "sawdust", "spray"): return "paintbrush.fill"
        case has("makeup", "beat_face", "skin", "nail", "scent", "designer", "layered", "fit_check", "thrift", "sole"): return "sparkles"
        case has("star", "aurora", "storm"): return "sparkles"
        case has("bloom", "petal", "leaves", "plant", "garden", "fresh_cut"): return "leaf.fill"
        case has("camera_film", "caption", "big_screen"): return "photo.fill"
        case has("holy", "wedding", "said_yes", "tiny_hands", "family", "people", "kids"): return "heart.fill"
        case has("fireworks", "lights_up", "season", "spooky", "fair", "cap_and_gown"): return "party.popper.fill"
        default: return "photo.fill"
        }
    }

    /// Deterministic two-color gradient seeded by the id, from an on-brand palette.
    static func gradient(for categoryId: String) -> [Color] {
        let palette: [[Color]] = [
            [Color(hex: 0x3A3E6C), Color(hex: 0x75619D)],
            [Color(hex: 0xA24C61), Color(hex: 0x3F2A52)],
            [Color(hex: 0x8387C3), Color(hex: 0x959BB5)],
            [Color(hex: 0x411528), Color(hex: 0x710C21)],
            [Color(hex: 0x3F2A52), Color(hex: 0x8A8CAC)],
            [Color(hex: 0x75619D), Color(hex: 0xE2A9C0)],
        ]
        var hash: UInt64 = 1469598103934665603
        for byte in categoryId.utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        return palette[Int(hash % UInt64(palette.count))]
    }
}

/// A designed placeholder tile for a category (gradient + glyph).
struct CategoryPlaceholder: View {
    let categoryId: String
    var body: some View {
        ZStack {
            LinearGradient(colors: CategoryGlyph.gradient(for: categoryId),
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: CategoryGlyph.symbol(for: categoryId))
                .font(.system(size: 30, weight: .light))
                .foregroundColor(.white.opacity(0.55))
        }
    }
}
