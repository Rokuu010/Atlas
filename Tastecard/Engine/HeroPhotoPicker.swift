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
    }

    static func inspect(_ image: CGImage) -> Signals {
        Signals(faceCount: faceCount(image),
                isLikelyDocument: isLikelyDocument(image),
                textRegions: textRegionCount(image))
    }

    /// True if the photo is unsuitable as a hero: a document/ID, faces of (likely other)
    /// people, or text-heavy (a screenshot, note, chat, or ID — likely private). A clean
    /// single-subject scene passes.
    static func isSensitiveForHero(_ signals: Signals) -> Bool {
        if signals.isLikelyDocument { return true }
        if signals.faceCount >= 2 { return true }   // groups / faces-of-others
        if signals.textRegions >= 6 { return true } // text-heavy => screenshot/notes/chat/ID
        return false
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
