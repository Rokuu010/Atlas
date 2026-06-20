//
//  ImageExport.swift
//  Tastecard
//
//  Renders any SwiftUI view to a shareable PNG (ImageRenderer, @3x). Used by the
//  single-theme share card (MiniThemeCard).
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
