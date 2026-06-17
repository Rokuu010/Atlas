//
//  Category.swift
//  Tastecard
//
//  The bundled, schema-validated category dataset (§6). Generated from
//  Atlas_Categories.md by scripts/generate_categories.py. detectionPrompts live here
//  for the engine and are NEVER rendered in the UI.
//

import Foundation

struct Category: Codable, Identifiable, Equatable {
    let id: String
    let displayName: String
    let tagline: String
    let detectionPrompts: [String]
    let rarityIndex: Double
    let threshold: Double

    var rarityTier: RarityTier { Rarity.tier(forIndex: rarityIndex) }
}

struct CategoryDataset: Codable, Equatable {
    let version: Int
    let categories: [Category]
}

enum CategoryStoreError: Error, LocalizedError, Equatable {
    case missingResource
    case decodingFailed(String)
    case schemaInvalid(String)

    var errorDescription: String? {
        switch self {
        case .missingResource: return "categories.json is missing from the app bundle."
        case .decodingFailed(let m): return "categories.json could not be decoded: \(m)"
        case .schemaInvalid(let m): return "categories.json failed validation: \(m)"
        }
    }
}

/// Loads and validates the bundled dataset. Validation is strict (§6): we refuse to
/// run on a malformed dataset rather than silently producing garbage themes.
enum CategoryStore {
    static let supportedVersion = 1

    static func loadBundled(bundle: Bundle = .main) throws -> [Category] {
        guard let url = bundle.url(forResource: "categories", withExtension: "json") else {
            throw CategoryStoreError.missingResource
        }
        let data = try Data(contentsOf: url)
        return try validate(data)
    }

    /// Decode + validate raw JSON. Separated out so tests can feed fixtures directly.
    static func validate(_ data: Data) throws -> [Category] {
        let dataset: CategoryDataset
        do {
            dataset = try JSONDecoder().decode(CategoryDataset.self, from: data)
        } catch {
            throw CategoryStoreError.decodingFailed(String(describing: error))
        }

        guard dataset.version == supportedVersion else {
            throw CategoryStoreError.schemaInvalid("unsupported version \(dataset.version)")
        }
        guard !dataset.categories.isEmpty else {
            throw CategoryStoreError.schemaInvalid("no categories present")
        }

        var seen = Set<String>()
        for c in dataset.categories {
            if c.id.isEmpty { throw CategoryStoreError.schemaInvalid("empty category id") }
            if !seen.insert(c.id).inserted {
                throw CategoryStoreError.schemaInvalid("duplicate category id \(c.id)")
            }
            if c.displayName.isEmpty {
                throw CategoryStoreError.schemaInvalid("\(c.id): empty displayName")
            }
            if c.detectionPrompts.isEmpty {
                throw CategoryStoreError.schemaInvalid("\(c.id): no detection prompts")
            }
            if !(0.0...1.0).contains(c.rarityIndex) {
                throw CategoryStoreError.schemaInvalid("\(c.id): rarityIndex out of range")
            }
            if !(0.0...1.0).contains(c.threshold) || c.threshold <= 0 {
                throw CategoryStoreError.schemaInvalid("\(c.id): threshold out of range")
            }
        }
        return dataset.categories
    }
}
