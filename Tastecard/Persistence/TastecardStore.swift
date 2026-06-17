//
//  TastecardStore.swift
//  Tastecard
//
//  Persists ONLY the derived, non-identifying card (§5, §8): theme ids, counts, opaque
//  PHAsset local identifiers, the local code, chosen theme index. No pixels, no raw
//  coordinates. Stored in UserDefaults (declared in PrivacyInfo.xcprivacy, reason CA92.1).
//

import Foundation

struct TastecardStore {
    private let defaults: UserDefaults
    private let key = "tastecard.currentCard.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    func load() -> Tastecard? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(Tastecard.self, from: data)
    }

    func save(_ card: Tastecard) {
        guard let data = try? encoder.encode(card) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
