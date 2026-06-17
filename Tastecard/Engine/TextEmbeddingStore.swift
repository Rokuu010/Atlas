//
//  TextEmbeddingStore.swift
//  Tastecard
//
//  Loads the precomputed, prompt-ensembled, L2-normalised category text embeddings
//  produced at build time by scripts/precompute_text_embeddings.py (§6). The text
//  encoder NEVER ships — only these vectors do.
//
//  Binary format (little-endian), self-describing so order/version are explicit:
//      magic   : 4 bytes  = "TCTE"
//      version : UInt32   = 1
//      dim     : UInt32
//      count   : UInt32
//      repeated count times:
//          idLen : UInt16
//          id    : idLen UTF-8 bytes
//          vec   : dim × Float32   (already L2-normalised)
//

import Foundation

struct TextEmbeddingStore {
    let dimension: Int
    private let vectors: [String: [Float]]

    var categoryIds: [String] { Array(vectors.keys) }
    func vector(for categoryId: String) -> [Float]? { vectors[categoryId] }

    static func loadBundled(bundle: Bundle = .main) throws -> TextEmbeddingStore {
        guard let url = bundle.url(forResource: "category_text_embeddings", withExtension: "bin") else {
            throw EmbedderError.modelMissing
        }
        let data = try Data(contentsOf: url)
        return try parse(data)
    }

    static func parse(_ data: Data) throws -> TextEmbeddingStore {
        var cursor = 0

        func read<T>(_ type: T.Type) throws -> T {
            let size = MemoryLayout<T>.size
            guard cursor + size <= data.count else {
                throw EmbedderError.modelLoadFailed("text embeddings truncated")
            }
            let value = data.subdata(in: cursor..<cursor + size).withUnsafeBytes {
                $0.loadUnaligned(as: T.self)
            }
            cursor += size
            return value
        }

        func readBytes(_ n: Int) throws -> Data {
            guard cursor + n <= data.count else {
                throw EmbedderError.modelLoadFailed("text embeddings truncated")
            }
            let slice = data.subdata(in: cursor..<cursor + n)
            cursor += n
            return slice
        }

        let magic = try readBytes(4)
        guard magic == Data("TCTE".utf8) else {
            throw EmbedderError.modelLoadFailed("bad magic in text embeddings")
        }
        let version: UInt32 = try read(UInt32.self)
        guard version == 1 else {
            throw EmbedderError.modelLoadFailed("unsupported text-embedding version \(version)")
        }
        let dim = Int(try read(UInt32.self))
        let count = Int(try read(UInt32.self))
        guard dim > 0, count > 0 else {
            throw EmbedderError.modelLoadFailed("empty text embeddings")
        }

        var map: [String: [Float]] = [:]
        map.reserveCapacity(count)
        for _ in 0..<count {
            let idLen = Int(try read(UInt16.self))
            let idData = try readBytes(idLen)
            guard let id = String(data: idData, encoding: .utf8) else {
                throw EmbedderError.modelLoadFailed("bad category id encoding")
            }
            let vecBytes = try readBytes(dim * MemoryLayout<Float32>.size)
            let vec: [Float] = vecBytes.withUnsafeBytes { raw in
                Array(raw.bindMemory(to: Float32.self))
            }
            map[id] = vec
        }
        return TextEmbeddingStore(dimension: dim, vectors: map)
    }
}
