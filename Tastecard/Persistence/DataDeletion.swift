//
//  DataDeletion.swift
//  Tastecard
//
//  §8 right to erasure / §10 5.1.1(v): one-tap deletion of everything the app stored
//  locally. There is no account and nothing was ever uploaded, so this is a complete,
//  honest "delete my data."
//

import Foundation

enum DataDeletion {
    /// Wipes the persisted card, the embedding cache, and any custom backgrounds.
    static func deleteEverything(store: TastecardStore = TastecardStore()) async {
        store.clear()
        LocalImageStore().deleteAll()

        // Wipe the whole cache directory (embeddings + backgrounds live under it).
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let cacheDir = base.appendingPathComponent("TastecardCache", isDirectory: true)
        try? FileManager.default.removeItem(at: cacheDir)
    }
}
