//
//  ThemeSelectorTests.swift
//  TastecardTests
//
//  Covers selection: the global photo minimum, most-photos-first ranking, that a card is
//  built from the strongest matched categories (the 10-photo floor governs only the saved
//  shadow set, NOT whether a card can be made), and "fewer than 3 matched -> warming up".
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

    func testFewerThanThreeMatchedCategoriesWarmsUp() {
        // Only two categories matched anything -> a card can't be built.
        let tallies = [
            tally("a", count: 20, score: 8),
            tally("b", count: 12, score: 4),
        ]
        XCTAssertEqual(ThemeSelector.select(tallies: tallies, photosAnalysed: 300),
                       .warmingUp(.notEnoughEvidence))
    }

    func testBuildsCardEvenWhenEveryCategoryIsUnderTheTenPhotoFloor() {
        // Regression: the 10-photo floor must NOT block a card. Three categories matched a
        // handful of photos each -> still build from the strongest, never "warming up".
        let tallies = [
            tally("a", count: 5, score: 5),
            tally("b", count: 4, score: 4),
            tally("c", count: 3, score: 3),
        ]
        guard case let .themes(selected) = ThemeSelector.select(tallies: tallies, photosAnalysed: 300) else {
            return XCTFail("expected a card, not warming up")
        }
        XCTAssertEqual(selected.map(\.categoryId), ["a", "b", "c"])
    }

    func testRanksByPhotoCount() {
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

    func testReturnsEveryMatchedCategory() {
        // select returns ALL matched categories (the engine caps the *display* to 6 and
        // derives the shadow set from those that reach the per-category floor).
        let tallies = (0..<8).map { tally("c\($0)", count: 30 - $0, score: 0) }
        guard case let .themes(selected) = ThemeSelector.select(tallies: tallies, photosAnalysed: 500) else {
            return XCTFail("expected themes")
        }
        XCTAssertEqual(selected.count, 8)
        XCTAssertEqual(selected.first?.categoryId, "c0")   // highest count (30)
        XCTAssertEqual(selected.last?.categoryId, "c7")    // lowest count (23)
    }
}
