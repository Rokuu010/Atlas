//
//  PhotoLibraryService.swift
//  Tastecard
//
//  Native Photos access (§2, §6). Supports limited authorization (the user may grant
//  all or only selected photos). Reads happen on-device only: we request downsampled
//  images with iCloud network access DISABLED, so nothing is fetched over the network —
//  this upholds the zero-network pillar and uses whatever is already on the device.
//
//  Split in two:
//    • PhotoLibraryService  — @MainActor, owns the @Published authorization state + UI flow.
//    • PhotoAssetLoader      — thread-safe fetch/image helpers used by the engine off-main.
//

import Photos
import UIKit

@MainActor
final class PhotoLibraryService: ObservableObject {

    @Published private(set) var authorization: PHAuthorizationStatus

    let loader = PhotoAssetLoader()

    init() {
        self.authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    var isAuthorized: Bool { authorization == .authorized || authorization == .limited }
    var isLimited: Bool { authorization == .limited }
    var isDenied: Bool { authorization == .denied || authorization == .restricted }

    /// Triggers the native permission prompt (call AFTER the priming screen, §4.2).
    /// We use `.readWrite` because it is the access level that grants reading existing
    /// photos and supports the limited library; the app never writes to the library.
    @discardableResult
    func requestAccess() async -> PHAuthorizationStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        self.authorization = status
        return status
    }

    func refreshAuthorization() {
        authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    /// Lets the user adjust which photos are shared when in limited mode.
    func presentLimitedLibraryPicker(from controller: UIViewController) {
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: controller)
    }
}

/// Thread-safe Photos helpers. PHAsset fetches and PHImageManager are safe off the main
/// thread, so the engine uses this directly from background tasks.
struct PhotoAssetLoader: Sendable {

    /// Opaque local identifiers for all image assets the app may see, newest first.
    /// In limited mode this is only the user-selected subset — by design.
    func imageAssetIdentifiers() -> [String] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.includeHiddenAssets = false
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var ids: [String] = []
        ids.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in ids.append(asset.localIdentifier) }
        return ids
    }

    func assets(for identifiers: [String]) -> [PHAsset] {
        guard !identifiers.isEmpty else { return [] }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }

    func asset(for identifier: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject
    }

    /// Requests a downsampled, on-device image. `isNetworkAccessAllowed = false` keeps
    /// everything local (no iCloud fetch) — central to the zero-network pillar.
    func requestImage(for asset: PHAsset, targetSide: CGFloat) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = false
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .exact
            options.isSynchronous = false

            // .highQualityFormat delivers a single callback (the best image available
            // locally). Resume once on that first callback — never gate on the "degraded"
            // flag, or an iCloud-only asset (network disabled) would hang forever.
            var resumed = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: targetSide, height: targetSide),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                if resumed { return }
                resumed = true
                continuation.resume(returning: image)
            }
        }
    }

    func requestImage(forIdentifier id: String, targetSide: CGFloat) async -> UIImage? {
        guard let asset = asset(for: id) else { return nil }
        return await requestImage(for: asset, targetSide: targetSide)
    }
}
