//
//  ImageDownsampler.swift
//  Tastecard
//
//  Memory-bounded thumbnailing. The engine must never hold thousands of full-res
//  images in memory (§6, §12): we downsample to the model's input size, infer, and
//  release. Uses ImageIO's CGImageSourceCreateThumbnailAtIndex, which decodes
//  directly to the target size without inflating the full bitmap.
//

import ImageIO
import CoreGraphics
import UIKit

enum ImageDownsampler {

    /// Decode `data` straight to a square thumbnail no larger than `maxPixel` on its
    /// longest edge. Returns nil if the data is not a decodable image.
    static func thumbnail(from data: Data, maxPixel: CGFloat) -> CGImage? {
        let srcOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let src = CGImageSourceCreateWithData(data as CFData, srcOptions) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        return CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary)
    }

    /// Square center-cropped, exactly `side`x`side`, suitable as a model input.
    static func squareThumbnail(from data: Data, side: Int) -> CGImage? {
        guard let thumb = thumbnail(from: data, maxPixel: CGFloat(side) * 1.4) else { return nil }
        let w = thumb.width, h = thumb.height
        let crop = min(w, h)
        let rect = CGRect(x: (w - crop) / 2, y: (h - crop) / 2, width: crop, height: crop)
        guard let cropped = thumb.cropping(to: rect) else { return thumb }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8,
            bytesPerRow: side * 4, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return cropped }
        ctx.interpolationQuality = .high
        ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: side, height: side))
        return ctx.makeImage() ?? cropped
    }
}
