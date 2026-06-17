//
//  ImageEmbedder.swift
//  Tastecard
//
//  The seam between the analysis pipeline and the model. iOS uses the Core ML SigLIP
//  image encoder (CoreMLImageEmbedder); tests use a deterministic mock. Both return an
//  L2-normalised embedding so similarity against the precomputed (also normalised) text
//  vectors is a plain dot product.
//

import CoreGraphics
import Foundation

protocol ImageEmbedder {
    /// Embedding dimension; must match the bundled text vectors.
    var dimension: Int { get }
    /// Required square input size in pixels (model-defined).
    var inputSide: Int { get }
    /// Returns an L2-normalised embedding for the image, or throws on failure.
    func embed(_ image: CGImage) throws -> [Float]
}

enum EmbedderError: Error, LocalizedError {
    case modelMissing
    case modelLoadFailed(String)
    case inferenceFailed(String)
    case dimensionMismatch(expected: Int, got: Int)

    var errorDescription: String? {
        switch self {
        case .modelMissing:
            return "The on-device analysis model is not installed in this build."
        case .modelLoadFailed(let m): return "Failed to load the model: \(m)"
        case .inferenceFailed(let m): return "Inference failed: \(m)"
        case .dimensionMismatch(let e, let g):
            return "Embedding dimension mismatch (model \(g), text vectors \(e))."
        }
    }
}

enum VectorMath {
    /// In-place L2 normalisation. No-op for a zero vector.
    static func l2Normalized(_ v: [Float]) -> [Float] {
        var sum: Float = 0
        for x in v { sum += x * x }
        let norm = sum.squareRoot()
        guard norm > 0 else { return v }
        return v.map { $0 / norm }
    }

    /// Dot product. For two L2-normalised vectors this equals cosine similarity.
    static func dot(_ a: [Float], _ b: [Float]) -> Float {
        let n = min(a.count, b.count)
        var sum: Float = 0
        var i = 0
        while i < n { sum += a[i] * b[i]; i += 1 }
        return sum
    }
}
