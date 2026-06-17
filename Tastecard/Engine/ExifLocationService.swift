//
//  ExifLocationService.swift
//  Tastecard
//
//  Computes the "Places" count from photo GPS (§6). We read PHAsset.location natively
//  (no raw EXIF parsing needed) and IMMEDIATELY coarsen it into clusters — we never
//  store raw coordinates (§8 data minimisation). No-EXIF libraries gracefully yield 0.
//
//  GeoClustering is pure (Foundation only) so it is unit-testable without Photos.
//

import Foundation
import Photos
import CoreLocation

/// Pure, dependency-free clustering. Greedy single-pass: a coordinate joins the first
/// existing cluster within `radiusMeters` of its centroid, otherwise starts a new one.
enum GeoClustering {

    struct Coordinate: Equatable {
        let latitude: Double
        let longitude: Double
    }

    static func distanceMeters(_ a: Coordinate, _ b: Coordinate) -> Double {
        let earth = 6_371_000.0
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earth * asin(min(1, h.squareRoot()))
    }

    /// Number of distinct places among the given coordinates.
    /// Default radius ~25km groups a city/region into a single "place."
    static func placesCount(_ coordinates: [Coordinate], radiusMeters: Double = 25_000) -> Int {
        guard !coordinates.isEmpty else { return 0 }
        // Sort for deterministic clustering regardless of input order.
        let sorted = coordinates.sorted {
            $0.latitude != $1.latitude ? $0.latitude < $1.latitude : $0.longitude < $1.longitude
        }
        var centroids: [Coordinate] = []
        for coord in sorted {
            if centroids.contains(where: { distanceMeters($0, coord) <= radiusMeters }) {
                continue
            }
            centroids.append(coord)
        }
        return centroids.count
    }
}

enum ExifLocationService {
    /// Coarse Places count from a set of assets. Coordinates are coarsened into clusters
    /// in-memory and discarded; nothing is persisted.
    static func placesCount(for assets: [PHAsset], radiusMeters: Double = 25_000) -> Int {
        let coords: [GeoClustering.Coordinate] = assets.compactMap { asset in
            guard let loc = asset.location else { return nil }
            return GeoClustering.Coordinate(
                latitude: loc.coordinate.latitude,
                longitude: loc.coordinate.longitude
            )
        }
        return GeoClustering.placesCount(coords, radiusMeters: radiusMeters)
    }
}
