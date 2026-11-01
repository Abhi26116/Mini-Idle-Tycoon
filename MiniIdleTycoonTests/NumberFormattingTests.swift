import XCTest
@testable import MiniIdleTycoon

/// Expected strings assume an English (US) locale, the simulator default.
final class NumberFormattingTests: XCTestCase {
    func testSmallNumbersKeepUpToOneDecimal() {
        XCTAssertEqual(950.0.abbreviated, "950")
        XCTAssertEqual(4.6.abbreviated, "4.6")
        XCTAssertEqual(0.0.abbreviated, "0")
    }

    func testThousandsAndBeyondUseSuffixes() {
        XCTAssertEqual(12_350.0.abbreviated, "12.35K")
        XCTAssertEqual(5.6e9.abbreviated, "5.6B")
        XCTAssertEqual(2e12.abbreviated, "2T")
    }

    func testRoundingRollsOverToNextSuffix() {
        XCTAssertEqual(999.96.abbreviated, "1K")
        XCTAssertEqual(999_996.0.abbreviated, "1M")
    }

    func testNonFiniteShowsInfinity() {
        XCTAssertEqual(Double.infinity.abbreviated, "∞")
        XCTAssertEqual(Double.nan.abbreviated, "∞")
    }

    func testBeyondLastSuffixFallsBackToScientific() {
        XCTAssertFalse(1e40.abbreviated.isEmpty)
        XCTAssertTrue(1e40.abbreviated.uppercased().contains("E"))
    }
}
