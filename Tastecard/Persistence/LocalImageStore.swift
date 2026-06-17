//
//  LocalImageStore.swift
//  Tastecard
//
//  Stores a user-chosen custom background in the app sandbox (local only — it never
//  leaves the device, §8). Validates type/size/dimensions before writing (§9). Files
//  are wiped by DataDeletion.
//

import UIKit

enum LocalImageStoreError: Error, LocalizedError {
    case tooLarge
    case invalidImage
    case dimensionsTooLarge

    var errorDescription: String? {
        switch self {
        case .tooLarge: return "That image is too large."
        case .invalidImage: return "That file isn't a supported image."
        case .dimensionsTooLarge: return "That image's dimensions are too large."
        }
    }
}

struct LocalImageStore {
    /// Caps to keep memory bounded and reject hostile inputs (§9).
    static let maxBytes = 25 * 1024 * 1024          // 25 MB
    static let maxDimension: CGFloat = 6000          // px per side

    private let directory: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        var dir = base.appendingPathComponent("TastecardCache/backgrounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try? dir.setResourceValues(values)
        self.directory = dir
    }

    /// Validates and stores image data, returning the stored filename.
    func store(data: Data) throws -> String {
        guard data.count <= Self.maxBytes else { throw LocalImageStoreError.tooLarge }
        guard let image = UIImage(data: data) else { throw LocalImageStoreError.invalidImage }
        guard image.size.width <= Self.maxDimension, image.size.height <= Self.maxDimension else {
            throw LocalImageStoreError.dimensionsTooLarge
        }
        // Re-encode to JPEG (strips any embedded metadata, normalises the format).
        guard let jpeg = image.jpegData(compressionQuality: 0.9) else {
            throw LocalImageStoreError.invalidImage
        }
        let filename = "bg_\(UUID().uuidString).jpg"
        try jpeg.write(to: directory.appendingPathComponent(filename), options: .atomic)
        return filename
    }

    func load(_ filename: String) -> UIImage? {
        UIImage(contentsOfFile: directory.appendingPathComponent(filename).path)
    }

    func delete(_ filename: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(filename))
    }

    func deleteAll() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
