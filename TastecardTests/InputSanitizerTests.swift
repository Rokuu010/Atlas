//
//  InputSanitizerTests.swift
//  TastecardTests
//
//  Display-name sanitisation + filename safety (§9).
//

import XCTest
@testable import Tastecard

final class InputSanitizerTests: XCTestCase {

    func testTrimsAndCollapsesWhitespace() {
        XCTAssertEqual(InputSanitizer.displayName("   Lina   the   Great  "), "Lina the Great")
    }

    func testCapsLength() {
        let long = String(repeating: "a", count: 100)
        XCTAssertEqual(InputSanitizer.displayName(long).count, InputSanitizer.maxDisplayNameLength)
    }

    func testStripsControlAndZeroWidth() {
        let nasty = "Li\u{200B}na\u{0007}\u{202E}"   // zero-width, bell, RTL override
        XCTAssertEqual(InputSanitizer.displayName(nasty), "Lina")
    }

    func testEmptyFallsBackToDefault() {
        XCTAssertEqual(InputSanitizer.displayNameOrDefault("   \u{200B} "), "My Tastecard")
        XCTAssertEqual(InputSanitizer.displayNameOrDefault("", default: "X"), "X")
    }

    func testFilenameSlug() {
        XCTAssertEqual(InputSanitizer.filenameSlug("Lina's Tastecard!"), "lina_s_tastecard")
        XCTAssertEqual(InputSanitizer.filenameSlug("   "), "tastecard")
        XCTAssertEqual(InputSanitizer.filenameSlug("café 2024"), "caf_2024")
    }

    func testNormalNameUnchanged() {
        XCTAssertEqual(InputSanitizer.displayName("Maya"), "Maya")
    }
}
