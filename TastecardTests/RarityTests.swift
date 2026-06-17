//
//  RarityTests.swift
//  TastecardTests
//
//  Rarity bands + card aggregation (§6), replacing the old hardcoded map.
//

import XCTest
@testable import Tastecard

final class RarityTests: XCTestCase {

    func testTierBands() {
        XCTAssertEqual(Rarity.tier(forIndex: 0.0), .common)
        XCTAssertEqual(Rarity.tier(forIndex: 0.32), .common)
        XCTAssertEqual(Rarity.tier(forIndex: 0.33), .rare)
        XCTAssertEqual(Rarity.tier(forIndex: 0.59), .rare)
        XCTAssertEqual(Rarity.tier(forIndex: 0.60), .epic)
        XCTAssertEqual(Rarity.tier(forIndex: 0.79), .epic)
        XCTAssertEqual(Rarity.tier(forIndex: 0.80), .legendary)
        XCTAssertEqual(Rarity.tier(forIndex: 1.0), .legendary)
    }

    func testCardAggregationLegendary() {
        XCTAssertEqual(Rarity.cardRarity(from: [.epic, .epic, .legendary]), .legendary)
        XCTAssertEqual(Rarity.cardRarity(from: [.legendary, .legendary, .legendary, .common]), .legendary)
    }

    func testCardAggregationEpic() {
        XCTAssertEqual(Rarity.cardRarity(from: [.epic, .epic, .rare]), .epic)
        XCTAssertEqual(Rarity.cardRarity(from: [.legendary, .epic, .common]), .epic)
    }

    func testCardAggregationRare() {
        XCTAssertEqual(Rarity.cardRarity(from: [.epic, .common, .common]), .rare)       // 1 high
        XCTAssertEqual(Rarity.cardRarity(from: [.rare, .rare, .rare]), .rare)           // 3 rare+
    }

    func testCardAggregationCommon() {
        XCTAssertEqual(Rarity.cardRarity(from: [.rare, .rare, .common]), .common)       // <3 rare+, 0 high
        XCTAssertEqual(Rarity.cardRarity(from: [.common, .common, .common]), .common)
    }

    func testTierOrdering() {
        XCTAssertLessThan(RarityTier.common, .rare)
        XCTAssertLessThan(RarityTier.rare, .epic)
        XCTAssertLessThan(RarityTier.epic, .legendary)
    }
}
