//
//  ExifClusteringTests.swift
//  TastecardTests
//
//  GPS -> coarse Places count (§6). No-EXIF yields 0; nearby points collapse to one place.
//

import XCTest
@testable import Tastecard

final class ExifClusteringTests: XCTestCase {

    private func c(_ lat: Double, _ lon: Double) -> GeoClustering.Coordinate {
        GeoClustering.Coordinate(latitude: lat, longitude: lon)
    }

    func testNoLocationsIsZero() {
        XCTAssertEqual(GeoClustering.placesCount([]), 0)
    }

    func testSingleLocationIsOne() {
        XCTAssertEqual(GeoClustering.placesCount([c(51.5074, -0.1278)]), 1)
    }

    func testNearbyPointsCollapseToOnePlace() {
        // Two points within central London (~3km apart) at the default 25km radius.
        let london1 = c(51.5074, -0.1278)
        let london2 = c(51.5155, -0.0922)
        XCTAssertEqual(GeoClustering.placesCount([london1, london2]), 1)
    }

    func testDistantPointsAreSeparatePlaces() {
        let london = c(51.5074, -0.1278)
        let paris = c(48.8566, 2.3522)
        let tokyo = c(35.6762, 139.6503)
        XCTAssertEqual(GeoClustering.placesCount([london, paris, tokyo]), 3)
    }

    func testClusteringIsOrderIndependent() {
        let pts = [c(51.5074, -0.1278), c(48.8566, 2.3522), c(51.5155, -0.0922), c(48.8606, 2.3376)]
        XCTAssertEqual(GeoClustering.placesCount(pts), 2)
        XCTAssertEqual(GeoClustering.placesCount(pts.reversed()), 2)
    }

    func testDistanceApproximation() {
        // London <-> Paris is ~344 km. Allow generous tolerance.
        let meters = GeoClustering.distanceMeters(c(51.5074, -0.1278), c(48.8566, 2.3522))
        XCTAssertEqual(meters, 343_000, accuracy: 15_000)
    }
}
