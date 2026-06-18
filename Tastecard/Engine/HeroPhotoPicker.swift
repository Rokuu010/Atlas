//
//  HeroPhotoPicker.swift
//  Tastecard
//
//  Auto-picks a hero photo per theme (§6). Biases toward clear, non-sensitive,
//  high-quality shots and away from screenshots; the engine additionally runs a Vision
//  sensitivity check (faces-of-others / document-like) on the top candidates before
//  committing one. Anything the user dislikes is one tap to change (DetailView).
//

import Foundation
import Vision
import CoreGraphics

/// One photo that cleared a category's threshold, with the signals used to rank it.
struct HeroCandidate: Equatable {
    let assetId: String
    let similarity: Float
    let isScreenshot: Bool
    let pixelCount: Int
}

enum HeroPhotoPicker {
    /// Ranks candidates best-first. Composite score favours model confidence, penalises
    /// screenshots, and gives a small bonus for resolution (clarity proxy).
    static func ranked(_ candidates: [HeroCandidate]) -> [HeroCandidate] {
        candidates.sorted { a, b in score(a) > score(b) }
    }

    static func bestAssetId(_ candidates: [HeroCandidate]) -> String? {
        ranked(candidates).first?.assetId
    }

    static func score(_ c: HeroCandidate) -> Double {
        let screenshotPenalty = c.isScreenshot ? 0.5 : 0.0
        // log-resolution bonus, capped, so a 48MP shot doesn't dominate a great 12MP one.
        let resolutionBonus = min(0.1, log10(Double(max(c.pixelCount, 1))) / 100.0)
        return Double(c.similarity) - screenshotPenalty + resolutionBonus
    }

    /// Asset-catalog name of the curated, locally-bundled fallback for a category,
    /// used when no auto-picked photo is suitable (missing/blurry/sensitive).
    static func fallbackImageName(forCategoryId id: String) -> String { "fallback_\(id)" }
}

/// Lightweight, bounded Vision checks. Run only on the top hero candidates so cost stays
/// small. Used to avoid surfacing documents/IDs or faces-of-others as a hero (§6).
enum PhotoQualityInspector {

    struct Signals {
        let faceCount: Int
        let isLikelyDocument: Bool
        let textRegions: Int
        let sharpness: Double    // Laplacian variance — higher = crisper
        let brightness: Double   // mean luma 0–255
    }

    static func inspect(_ image: CGImage) -> Signals {
        let q = qualityMetrics(image)
        return Signals(faceCount: faceCount(image),
                       isLikelyDocument: isLikelyDocument(image),
                       textRegions: textRegionCount(image),
                       sharpness: q.sharpness,
                       brightness: q.brightness)
    }

    /// Sensitive content we never surface as a hero: documents/IDs, faces of (likely
    /// other) people, or text-heavy images (screenshots, notes, chats, leaflets).
    static func isSensitiveForHero(_ signals: Signals) -> Bool {
        if signals.isLikelyDocument { return true }
        if signals.faceCount >= 2 { return true }   // groups / faces-of-others
        if signals.textRegions >= 4 { return true } // text-heavy => screenshot/note/leaflet/ID
        return false
    }

    /// Unsuitable as a hero: sensitive, or visually poor (near-black/blown-out/very blurry).
    static func isUnsuitableHero(_ signals: Signals) -> Bool {
        if isSensitiveForHero(signals) { return true }
        if signals.brightness < 18 || signals.brightness > 248 { return true }
        if signals.sharpness < 12 { return true }   // extremely blurry
        return false
    }

    /// Mean brightness + Laplacian variance from a 64x64 grayscale downscale.
    private static func qualityMetrics(_ image: CGImage) -> (sharpness: Double, brightness: Double) {
        let side = 64
        var pixels = [UInt8](repeating: 0, count: side * side)
        let gray = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(data: &pixels, width: side, height: side, bitsPerComponent: 8,
                                  bytesPerRow: side, space: gray,
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            return (sharpness: 1000, brightness: 128)
        }
        ctx.interpolationQuality = .low
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))

        var sum = 0.0
        for p in pixels { sum += Double(p) }
        let brightness = sum / Double(pixels.count)

        func at(_ x: Int, _ y: Int) -> Double { Double(pixels[y * side + x]) }
        var lap = [Double]()
        lap.reserveCapacity((side - 2) * (side - 2))
        for y in 1..<(side - 1) {
            for x in 1..<(side - 1) {
                lap.append(4 * at(x, y) - at(x - 1, y) - at(x + 1, y) - at(x, y - 1) - at(x, y + 1))
            }
        }
        let mean = lap.reduce(0, +) / Double(lap.count)
        var v = 0.0
        for l in lap { let d = l - mean; v += d * d }
        return (sharpness: v / Double(lap.count), brightness: brightness)
    }

    /// Number of recognised text regions — a cheap, reliable signal for "this is a
    /// screenshot / note / chat", which we never want to surface as a hero.
    private static func textRegionCount(_ image: CGImage) -> Int {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
            return request.results?.count ?? 0
        } catch {
            return 0
        }
    }

    private static func faceCount(_ image: CGImage) -> Int {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
            return request.results?.count ?? 0
        } catch {
            return 0
        }
    }

    private static func isLikelyDocument(_ image: CGImage) -> Bool {
        if #available(iOS 15.0, *) {
            let request = VNDetectDocumentSegmentationRequest()
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
                if let obs = (request.results as? [VNRectangleObservation])?.first {
                    // High-confidence near-full-frame rectangle => document/screenshot of text.
                    return obs.confidence > 0.9
                }
            } catch {
                return false
            }
        }
        return false
    }
}
