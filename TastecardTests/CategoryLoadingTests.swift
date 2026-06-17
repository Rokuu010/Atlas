//
//  CategoryLoadingTests.swift
//  TastecardTests
//
//  Schema validation of the bundled dataset (§6). We refuse malformed data rather than
//  silently producing garbage themes.
//

import XCTest
@testable import Tastecard

final class CategoryLoadingTests: XCTestCase {

    private func json(_ s: String) -> Data { Data(s.utf8) }

    func testValidDatasetDecodes() throws {
        let data = json("""
        {"version":1,"categories":[
          {"id":"coffee","displayName":"Coffee","tagline":"t","detectionPrompts":["a cup of coffee"],"rarityIndex":0.12,"threshold":0.2}
        ]}
        """)
        let cats = try CategoryStore.validate(data)
        XCTAssertEqual(cats.count, 1)
        XCTAssertEqual(cats[0].rarityTier, .common)
    }

    func testUnsupportedVersionRejected() {
        let data = json("""
        {"version":99,"categories":[
          {"id":"a","displayName":"A","tagline":"t","detectionPrompts":["x"],"rarityIndex":0.5,"threshold":0.2}
        ]}
        """)
        XCTAssertThrowsError(try CategoryStore.validate(data))
    }

    func testDuplicateIdRejected() {
        let data = json("""
        {"version":1,"categories":[
          {"id":"a","displayName":"A","tagline":"t","detectionPrompts":["x"],"rarityIndex":0.5,"threshold":0.2},
          {"id":"a","displayName":"A2","tagline":"t","detectionPrompts":["y"],"rarityIndex":0.5,"threshold":0.2}
        ]}
        """)
        XCTAssertThrowsError(try CategoryStore.validate(data))
    }

    func testEmptyPromptsRejected() {
        let data = json("""
        {"version":1,"categories":[
          {"id":"a","displayName":"A","tagline":"t","detectionPrompts":[],"rarityIndex":0.5,"threshold":0.2}
        ]}
        """)
        XCTAssertThrowsError(try CategoryStore.validate(data))
    }

    func testOutOfRangeThresholdRejected() {
        let data = json("""
        {"version":1,"categories":[
          {"id":"a","displayName":"A","tagline":"t","detectionPrompts":["x"],"rarityIndex":0.5,"threshold":1.5}
        ]}
        """)
        XCTAssertThrowsError(try CategoryStore.validate(data))
    }

    func testBundledDatasetLoads() throws {
        // The real generated categories.json ships in the app bundle (the unit-test target
        // is hosted by the app, so AppModel resolves to the app bundle).
        let appBundle = Bundle(for: AppModel.self)
        do {
            let cats = try CategoryStore.loadBundled(bundle: appBundle)
            XCTAssertGreaterThanOrEqual(cats.count, 60)
            XCTAssertTrue(cats.allSatisfy { !$0.detectionPrompts.isEmpty })
            XCTAssertTrue(cats.allSatisfy { (0...1).contains($0.rarityIndex) })
        } catch CategoryStoreError.missingResource {
            throw XCTSkip("categories.json not in this test's bundle configuration")
        }
    }
}
