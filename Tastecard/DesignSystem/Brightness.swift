//
//  Brightness.swift
//  Tastecard
//
//  Native port of analyzeImageBrightness() from App.tsx.
//  Samples a downscaled 10x10 version of the image, averages RGB, and computes
//  a luminance-weighted RMS brightness. Threshold 135 (kept identical) decides
//  whether the custom background is "dark" — which drives adaptive text color,
//  glass tint, and the readability scrim.
//

import SwiftUI
import UIKit

enum Brightness {

    /// Returns true when the image is dark enough to warrant light text + a dark scrim.
    /// Mirrors: brightness = sqrt(0.299*r^2 + 0.587*g^2 + 0.114*b^2) < 135
    static func isDark(_ image: UIImage) -> Bool {
        averageBrightness(image).map { $0 < 135 } ?? false
    }

    /// Same luminance-weighted RMS test for a solid colour (used by the custom colour wheel).
    static func isDark(_ color: Color) -> Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a) else { return false }
        let R = Double(r) * 255, G = Double(g) * 255, B = Double(b) * 255
        return (0.299 * R * R + 0.587 * G * G + 0.114 * B * B).squareRoot() < 135
    }

    /// The luminance-weighted RMS brightness of a 10x10 downscale, or nil if it
    /// could not be sampled (matching the JS try/catch fallback, which keeps light text).
    static func averageBrightness(_ image: UIImage) -> Double? {
        guard let cg = image.cgImage else { return nil }

        let side = 10
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * side
        var pixels = [UInt8](repeating: 0, count: side * side * bytesPerPixel)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(
            data: &pixels,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        ctx.interpolationQuality = .low
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))

        var rSum = 0.0, gSum = 0.0, bSum = 0.0
        let count = Double(side * side)
        for i in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            rSum += Double(pixels[i])
            gSum += Double(pixels[i + 1])
            bSum += Double(pixels[i + 2])
        }
        let avgR = rSum / count
        let avgG = gSum / count
        let avgB = bSum / count
        return (0.299 * avgR * avgR + 0.587 * avgG * avgG + 0.114 * avgB * avgB).squareRoot()
    }
}
