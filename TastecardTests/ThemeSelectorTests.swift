//
//  ThemeSelectorTests.swift
//  TastecardTests
//
//  Covers the emergent-theme selection rules: the global photo minimum, the per-category
//  10-photo floor, "fewer than 3 qualifying categories -> warming up", most-photos-first
//  ranking, and that EVERY qualifying category is returned (the engine caps the display).
//

import XCTest
@testable import Tastecard

final class ThemeSelectorTests: XCTestCase {

    private func tally(_ id: String, count: Int, score: Double) -> CategoryTally {
        CategoryTally(categoryId: id, count: count, score: score)
    }

    func testBelowGlobalMinimumWarmsUp() {
        let outcome = ThemeSelector.select(
            tallies: [tally("a", count: 20, score: 5)],
            photosAnalysed: 10
        )
        XCTAssertEqual(outcome, .warmingUp(.notEnoughPhotos))
    }

    func testFewerThanThreeQualifyingCategoriesWarmsUp() {
        // Only two categories reach the 10-photo floor; "c" is under it.
        let tallies = [
            tally("a", count: 20, score: 8),
            tally("b", count: 12, score: 4),
            tally("c", count: 9, score: 9),
        ]
        XCTAssertEqual(ThemeSelector.select(tallies: tallies, photosAnalysed: 300),
                       .warmingUp(.notEnoughEvidence))
    }

    func testCategoryUnderTenPhotosNeverQualifies() {
        // Plenty of categories, all just under the floor -> no card.
        let tallies = (0..<6).map { tally("c\($0)", count: 9, score: 100) }
        XCTAssertEqual(ThemeSelector.select(tallies: tallies, photosAnalysed: 500),
                       .warmingUp(.notEnoughEvidence))
    }

    func testReturnsQualifiedRankedByPhotoCount() {
        let tallies = [
            tally("few", count: 10, score: 9.0),
            tally("most", count: 40, score: 1.0),
            tally("mid", count: 25, score: 5.0),
        ]
        guard case let .themes(selected) = ThemeSelector.select(tallies: tallies, photosAnalysed: 500) else {
            return XCTFail("expected themes")
        }
        XCTAssertEqual(selected.map(\.categoryId), ["most", "mid", "few"])
    }

    func testReturnsEveryQualifyingCategoryForTheShadowSet() {
        // select returns ALL qualifying categories (the engine caps the *display* to 6).
        let tallies = (0..<8).map { tally("c\($0)", count: 10 + (8 - $0), score: 0) }
        guard case let .themes(selected) = ThemeSelector.select(tallies: tallies, photosAnalysed: 500) else {
            return XCTFail("expected themes")
        }
        XCTAssertEqual(selected.count, 8)
        XCTAssertEqual(selected.first?.categoryId, "c0")   // highest count (18)
        XCTAssertEqual(selected.last?.categoryId, "c7")    // lowest count (11)
    }

    func testExactlyThreeQualifyingCategoriesBuildsCard() {
        let tallies = [
            tally("a", count: 30, score: 3),
            tally("b", count: 20, score: 2),
            tally("c", count: 10, score: 1),
        ]
        guard case let .themes(selected) = ThemeSelector.select(tallies: tallies, photosAnalysed: 500) else {
            return XCTFail("expected themes")
        }
        XCTAssertEqual(selected.map(\.categoryId), ["a", "b", "c"])
    }
}
