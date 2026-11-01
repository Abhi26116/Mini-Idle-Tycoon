import XCTest
@testable import MiniIdleTycoon

final class GameMathTests: XCTestCase {
    private let accuracy = 1e-9

    // MARK: - Costs

    func testUpgradeCostAtLevelZeroIsBaseCost() {
        XCTAssertEqual(GameMath.upgradeCost(baseCost: 4, currentLevel: 0), 4, accuracy: accuracy)
    }

    func testUpgradeCostGrows15PercentPerLevel() {
        XCTAssertEqual(GameMath.upgradeCost(baseCost: 4, currentLevel: 1), 4.6, accuracy: accuracy)
        XCTAssertEqual(GameMath.upgradeCost(baseCost: 4, currentLevel: 2), 5.29, accuracy: accuracy)
    }

    func testUpgradeCostTreatsNegativeLevelAsZero() {
        XCTAssertEqual(GameMath.upgradeCost(baseCost: 10, currentLevel: -3), 10, accuracy: accuracy)
    }

    func testManagerCostIsHundredTimesBaseCost() {
        let station = makeStation(baseCost: 60)
        XCTAssertEqual(GameMath.managerCost(for: station), 6_000, accuracy: accuracy)
    }

    // MARK: - Revenue

    func testUnboughtStationEarnsNothing() {
        XCTAssertEqual(GameMath.revenuePerCycle(baseRevenue: 50, level: 0), 0)
    }

    func testRevenueScalesWithLevelAndMultiplier() {
        XCTAssertEqual(GameMath.revenuePerCycle(baseRevenue: 5, level: 3), 15, accuracy: accuracy)
        XCTAssertEqual(GameMath.revenuePerCycle(baseRevenue: 5, level: 3, multiplier: 2), 30, accuracy: accuracy)
    }

    func testRevenuePerSecondDividesByCycleDuration() {
        let station = makeStation(baseRevenue: 60, processingTime: 3, level: 1)
        XCTAssertEqual(GameMath.revenuePerSecond(for: station), 20, accuracy: accuracy)
        XCTAssertEqual(GameMath.revenuePerSecond(for: station, multiplier: 2), 40, accuracy: accuracy)
    }

    func testRevenuePerSecondIsZeroForZeroLengthCycle() {
        let station = makeStation(processingTime: 0, level: 1)
        XCTAssertEqual(GameMath.revenuePerSecond(for: station), 0)
    }

    // MARK: - Production Cycles

    func testCompletedCyclesSplitsCountAndRemainder() {
        let result = GameMath.completedCycles(progress: 2.5, cycleDuration: 1)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.remainder, 0.5, accuracy: accuracy)
    }

    func testCompletedCyclesWithNoProgress() {
        let result = GameMath.completedCycles(progress: 0, cycleDuration: 3)
        XCTAssertEqual(result.count, 0)
        XCTAssertEqual(result.remainder, 0)
    }

    func testCompletedCyclesClampsNegativeProgress() {
        let result = GameMath.completedCycles(progress: -5, cycleDuration: 3)
        XCTAssertEqual(result.count, 0)
        XCTAssertEqual(result.remainder, 0)
    }

    func testCompletedCyclesWithZeroDurationKeepsProgress() {
        let result = GameMath.completedCycles(progress: 4, cycleDuration: 0)
        XCTAssertEqual(result.count, 0)
        XCTAssertEqual(result.remainder, 4)
    }

    // MARK: - Offline Progress

    func testCreditedOfflineTimeIsNeverNegative() {
        let now = Date()
        XCTAssertEqual(GameMath.creditedOfflineTime(from: now, to: now.addingTimeInterval(-600)), 0)
    }

    func testCreditedOfflineTimeWithinCap() {
        let now = Date()
        XCTAssertEqual(GameMath.creditedOfflineTime(from: now, to: now.addingTimeInterval(3_600)),
                       3_600, accuracy: accuracy)
    }

    func testCreditedOfflineTimeIsCapped() {
        let now = Date()
        XCTAssertEqual(GameMath.creditedOfflineTime(from: now, to: now.addingTimeInterval(24 * 3_600)),
                       GameMath.maxOfflineDuration)
    }

    // MARK: - Helpers

    private func makeStation(baseCost: Double = 1,
                             baseRevenue: Double = 1,
                             processingTime: TimeInterval = 1,
                             level: Int = 0) -> Station {
        Station(id: "test", name: "Test",
                baseCost: baseCost, baseRevenue: baseRevenue,
                processingTimeInSeconds: processingTime, currentLevel: level)
    }
}
