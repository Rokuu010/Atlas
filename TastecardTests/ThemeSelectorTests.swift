//
//  ThemeSelectorTests.swift
//  TastecardTests
//
//  Covers the §4 emergent-theme selection rules: global minimum, evidence floor scaling,
//  the 3–6 selection, the >6 cap, the "fewer than 3 clear the bar -> warming up" state,
//  and the top-3-by-strength refinement.
//

import XCTest
@testable import Tastecard

final class ThemeSelectorTests: XCTestCase {

    private func tally(_ id: String, count: Int, score: Double) -> CategoryTally {
        CategoryTally(categoryId: id, count: count, score: score)
    }

    func testBelowGlobalMinimumWarmsUp() {
        let outcome = ThemeSelector.select(
            tallies: [tally("a", count: 5, score: 5)],
            photosAnalysed: 10
        )
        XCTAssertEqual(outcome, .warmingUp(.notEnoughPhotos))
    }

    func testFewerThanThreeClearedWarmsUp() {
        // floor at 100 photos = 3. Only two categories reach it.
        let tallies = [
            tally("a", count: 8, score: 8),
            tally("b", count: 4, score: 4),
            tally("c", count: 2, score: 2),
        ]
        let outcome = ThemeSelector.select(tallies: tallies, photosAnalysed: 100)
        XCTAssertEqual(outcome, .warmingUp(.notEnoughEvidence))
    }

    func testSelectsThreeToSixRankedByScore() {
        let tallies = [
            tally("low", count: 10, score: 1.0),
            tally("high", count: 10, score: 9.0),
            tally("mid", count: 10, score: 5.0),
            tally("mid2", count: 10, score: 4.0),
        ]
        guard case let .themes(selected) = ThemeSelector.select(tallies: tallies, photosAnalysed: 100) else {
            return XCTFail("expected themes")
        }
        XCTAssertEqual(selected.map(\.categoryId), ["high", "mid", "mid2", "low"])
    }

    func testCapsAtSixByStrength() {
        let tallies = (0..<10).map { tally("c\($0)", count: 10, score: Double(10 - $0)) }
        guard case let .themes(selected) = ThemeSelector.select(tallies: tallies, photosAnalysed: 100) else {
            return XCTFail("expected themes")
        }
        XCTAssertEqual(selected.count, 6)
        XCTAssertEqual(selected.map(\.categoryId), ["c0", "c1", "c2", "c3", "c4", "c5"])
    }

    func testEvidenceFloorScalesWithLibrarySize() {
        let config = SelectionConfig()
        XCTAssertEqual(config.evidenceFloor(librarySize: 100), 3)
        XCTAssertEqual(config.evidenceFloor(librarySize: 1000), 5)
        XCTAssertEqual(config.evidenceFloor(librarySize: 2000), 10)
        XCTAssertEqual(config.evidenceFloor(librarySize: 3000), 15)
    }

    func testLargeLibraryRequiresMoreEvidence() {
        // At 2000 photos the floor is 10; counts of 6 do NOT clear it.
        let tallies = [
            tally("a", count: 9, score: 9),
            tally("b", count: 8, score: 8),
            tally("c", count: 7, score: 7),
        ]
        XCTAssertEqual(ThemeSelector.select(tallies: tallies, photosAnalysed: 2000),
                       .warmingUp(.notEnoughEvidence))
    }

    func testTopThreeByStrengthFillsSlotEvenWhenUnderFloor() {
        // 2000 photos -> floor 10. A,B,C clear it; D is under floor but the strongest.
        let tallies = [
            tally("d_strong_underfloor", count: 5, score: 100),
            tally("a", count: 30, score: 30),
            tally("b", count: 20, score: 20),
            tally("c", count: 15, score: 15),
        ]
        guard case let .themes(selected) = ThemeSelector.select(tallies: tallies, photosAnalysed: 2000) else {
            return XCTFail("expected themes")
        }
        // D included via the top-3-by-strength refinement; ranked first by score.
        XCTAssertEqual(selected.first?.categoryId, "d_strong_underfloor")
        XCTAssertEqual(Set(selected.map(\.categoryId)), ["d_strong_underfloor", "a", "b", "c"])
    }

    func testUnderFloorAndNotTopThreeIsExcluded() {
        // 2000 photos -> floor 10. Three clear it; a 4th is under floor and rank 4 -> excluded.
        let tallies = [
            tally("a", count: 30, score: 30),
            tally("b", count: 20, score: 20),
            tally("c", count: 15, score: 15),
            tally("weak", count: 5, score: 1),
        ]
        guard case let .themes(selected) = ThemeSelector.select(tallies: tallies, photosAnalysed: 2000) else {
            return XCTFail("expected themes")
        }
        XCTAssertEqual(selected.map(\.categoryId), ["a", "b", "c"])
    }
}
