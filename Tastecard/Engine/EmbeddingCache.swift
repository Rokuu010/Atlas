//
//  EmbeddingCache.swift
//  Tastecard
//
//  Persists per-asset image embeddings keyed by PHAsset.localIdentifier so re-runs are
//  incremental (§6, §12) — we only embed photos we haven't seen. Stored in the app
//  sandbox (Application Support), excluded from iCloud backup. Embeddings are derived,
//  non-identifying vectors; wiped by DataDeletion (§8).
//

import Foundation

actor EmbeddingCache {
    private let fileURL: URL
    private let dimension: Int
    private var memory: [String: [Float]]
    private var dirty = false

    init(dimension: Int, directory: URL? = nil) {
        self.dimension = dimension
        let dir = directory ?? EmbeddingCache.defaultDirectory()
        self.fileURL = dir.appendingPathComponent("embeddings_v1_dim\(dimension).bin")
        self.memory = EmbeddingCache.read(from: fileURL, dimension: dimension)
    }

    func embedding(for assetId: String) -> [Float]? { memory[assetId] }

    func store(_ embedding: [Float], for assetId: String) {
        guard embedding.count == dimension else { return }
        memory[assetId] = embedding
        dirty = true
    }

    /// Drops cache entries for assets that no longer exist (deleted from the library).
    func prune(keeping liveIds: Set<String>) {
        let before = memory.count
        memory = memory.filter { liveIds.contains($0.key) }
        if memory.count != before { dirty = true }
    }

    func flush() {
        guard dirty else { return }
        EmbeddingCache.write(memory, to: fileURL, dimension: dimension)
        dirty = false
    }

    func wipe() {
        memory.removeAll()
        try? FileManager.default.removeItem(at: fileURL)
        dirty = false
    }

    // MARK: - Storage

    static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("TastecardCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableDir = dir
        try? mutableDir.setResourceValues(values)
        return dir
    }

    private static func read(from url: URL, dimension: Int) -> [String: [Float]] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        var cursor = 0
        func readU32() -> UInt32? {
            guard cursor + 4 <= data.count else { return nil }
            let v = data.subdata(in: cursor..<cursor + 4).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
            cursor += 4
            return v
        }
        guard let count = readU32() else { return [:] }
        var map: [String: [Float]] = [:]
        for _ in 0..<count {
            guard let idLen = readU32(), cursor + Int(idLen) <= data.count else { break }
            let idData = data.subdata(in: cursor..<cursor + Int(idLen)); cursor += Int(idLen)
            guard let id = String(data: idData, encoding: .utf8) else { break }
            let vecBytes = dimension * MemoryLayout<Float32>.size
            guard cursor + vecBytes <= data.count else { break }
            let slice = data.subdata(in: cursor..<cursor + vecBytes); cursor += vecBytes
            map[id] = slice.withUnsafeBytes { Array($0.bindMemory(to: Float32.self)) }
        }
        return map
    }

    private static func write(_ map: [String: [Float]], to url: URL, dimension: Int) {
        var data = Data()
        var count = UInt32(map.count)
        withUnsafeBytes(of: &count) { data.append(contentsOf: $0) }
        for (id, vec) in map {
            let idBytes = Array(id.utf8)
            var idLen = UInt32(idBytes.count)
            withUnsafeBytes(of: &idLen) { data.append(contentsOf: $0) }
            data.append(contentsOf: idBytes)
            vec.withUnsafeBytes { data.append(contentsOf: $0) }
        }
        try? data.write(to: url, options: .atomic)
    }
}
