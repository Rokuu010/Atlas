//
//  ImageExport.swift
//  Tastecard
//
//  Shared helpers for the engagement features: render any SwiftUI view to a shareable PNG
//  (ImageRenderer, @3x) and pre-resolve theme hero images so renders/slides aren't blank.
//

import SwiftUI
import UIKit

@MainActor
enum ImageExport {
    /// Renders a view at a fixed size to a temp PNG and returns its file URL (for sharing).
    static func renderToTempFile<V: View>(_ view: V,
                                           width: CGFloat,
                                           height: CGFloat,
                                           scale: CGFloat = 3,
                                           filename: String) -> URL? {
        let renderer = ImageRenderer(content: view.frame(width: width, height: height))
        renderer.scale = scale
        renderer.isOpaque = true
        renderer.proposedSize = ProposedViewSize(width: width, height: height)
        guard let image = renderer.uiImage, let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

/// Pre-resolves theme hero images (keyed by PHAsset local id) for slides/renders.
enum ThemeImageLoader {
    static func heroes(for themes: [EmergentTheme], targetSide: CGFloat = 900) async -> [String: UIImage] {
        let loader = PhotoAssetLoader()
        var dict: [String: UIImage] = [:]
        for theme in themes {
            guard let id = theme.heroPhotoLocalId, dict[id] == nil else { continue }
            if let img = await loader.requestImage(forIdentifier: id, targetSide: targetSide) {
                dict[id] = img
            }
        }
        return dict
    }
}
