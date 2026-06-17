//
//  AssetImage.swift
//  Tastecard
//
//  Asynchronously loads a photo by its PHAsset local identifier for display. Falls back
//  to a bundled, locally-licensed category image, then to a generated gradient — never a
//  network hotlink (privacy + offline + no CORS-tainted export). Results are cached in
//  memory so scrolling and the export are smooth.
//

import SwiftUI
import UIKit

final class AssetImageCache {
    static let shared = AssetImageCache()
    private let cache = NSCache<NSString, UIImage>()
    private init() { cache.countLimit = 60 }

    func image(forKey key: String) -> UIImage? { cache.object(forKey: key as NSString) }
    func set(_ image: UIImage, forKey key: String) { cache.setObject(image, forKey: key as NSString) }
    func clear() { cache.removeAllObjects() }

    /// Synchronous accessor used by the export renderer (must be pre-warmed).
    func cachedOrNil(_ key: String) -> UIImage? { image(forKey: key) }
}

struct AssetImage: View {
    let assetId: String?
    var fallbackName: String?
    var targetSide: CGFloat = 600

    @State private var image: UIImage?
    private let loader = PhotoAssetLoader()

    var body: some View {
        GeometryReader { geo in
            content
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .task(id: assetId) { await load() }
    }

    @ViewBuilder private var content: some View {
        if let image {
            Image(uiImage: image).resizable().scaledToFill()
        } else if let fallbackName, UIImage(named: fallbackName) != nil {
            Image(fallbackName).resizable().scaledToFill()
        } else {
            PlaceholderGradient()
        }
    }

    private func cacheKey(_ id: String) -> String { "\(id)#\(Int(targetSide))" }

    private func load() async {
        guard let assetId else { image = nil; return }
        if let cached = AssetImageCache.shared.image(forKey: cacheKey(assetId)) {
            image = cached
            return
        }
        if let loaded = await loader.requestImage(forIdentifier: assetId, targetSide: targetSide) {
            AssetImageCache.shared.set(loaded, forKey: cacheKey(assetId))
            image = loaded
        }
    }
}

/// Neutral, on-brand placeholder used when no photo/fallback is available.
struct PlaceholderGradient: View {
    var body: some View {
        LinearGradient(
            colors: [Color(hex: 0x3A3E6C), Color(hex: 0x75619D), Color(hex: 0x8A8CAC)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "photo")
                .font(.system(size: 22, weight: .light))
                .foregroundColor(.white.opacity(0.5))
        )
    }
}

/// Loads hero images synchronously into the cache before an export render (§7).
enum HeroImagePrewarmer {
    static func prewarm(assetIds: [String], targetSide: CGFloat = 800) async {
        let loader = PhotoAssetLoader()
        for id in assetIds {
            let key = "\(id)#\(Int(targetSide))"
            if AssetImageCache.shared.image(forKey: key) != nil { continue }
            if let img = await loader.requestImage(forIdentifier: id, targetSide: targetSide) {
                AssetImageCache.shared.set(img, forKey: key)
            }
        }
    }
}
