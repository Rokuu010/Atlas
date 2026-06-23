//
//  SnapshotRenderer.swift
//  Tastecard
//
//  SwiftUI ImageRenderer → 9:16 PNG at 3× (the clean native swap for html-to-image with
//  pixelRatio: 3, §2/§7). Runs on the main actor as ImageRenderer requires.
//

import SwiftUI
import UIKit

@MainActor
enum SnapshotRenderer {
    static func renderImage(_ view: SnapshotCardView, scale: CGFloat = 3) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(width: view.baseWidth, height: view.baseHeight)
        renderer.isOpaque = true
        return renderer.uiImage
    }

    static func renderPNG(_ view: SnapshotCardView, scale: CGFloat = 3) -> Data? {
        renderImage(view, scale: scale)?.pngData()
    }

    /// Renders and writes a PNG to a temp file named from the (sanitised) display name.
    static func renderToTempFile(_ view: SnapshotCardView, displayName: String, scale: CGFloat = 3) -> URL? {
        guard let data = renderPNG(view, scale: scale) else { return nil }
        let slug = InputSanitizer.filenameSlug(displayName)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(slug)_rollcard.png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
