import XCTest
@testable import MiniIdleTycoon

final class PlayerProfileTests: XCTestCase {
    func testSpendCoinsDeductsWhenAffordable() {
        var profile = PlayerProfile(totalCoins: 10)
        XCTAssertTrue(profile.spendCoins(4))
        XCTAssertEqual(profile.totalCoins, 6)
    }

    func testSpendCoinsFailsWhenTooExpensive() {
        var profile = PlayerProfile(totalCoins: 3)
        XCTAssertFalse(profile.spendCoins(4))
        XCTAssertEqual(profile.totalCoins, 3)
    }

    func testSpendCoinsRejectsNegativeCost() {
        var profile = PlayerProfile(totalCoins: 3)
        XCTAssertFalse(profile.spendCoins(-5))
        XCTAssertEqual(profile.totalCoins, 3)
    }

    func testCanAffordExactBalance() {
        XCTAssertTrue(PlayerProfile(totalCoins: 5).canAfford(5))
        XCTAssertFalse(PlayerProfile(totalCoins: 5).canAfford(5.01))
    }

    func testAddCoinsIgnoresNonPositiveAndNaN() {
        var profile = PlayerProfile(totalCoins: 10)
        profile.addCoins(0)
        profile.addCoins(-3)
        profile.addCoins(.nan)
        XCTAssertEqual(profile.totalCoins, 10)

        profile.addCoins(2.5)
        XCTAssertEqual(profile.totalCoins, 12.5)
    }
}

final class StationTests: XCTestCase {
    func testIsOwnedOnlyFromLevelOne() {
        var station = Station(id: "s", name: "S", baseCost: 1, baseRevenue: 1, processingTimeInSeconds: 2)
        XCTAssertFalse(station.isOwned)
        station.currentLevel = 1
        XCTAssertTrue(station.isOwned)
    }

    func testProgressFractionIsClampedToOne() {
        var station = Station(id: "s", name: "S", baseCost: 1, baseRevenue: 1, processingTimeInSeconds: 2)
        station.currentProgress = 1
        XCTAssertEqual(station.progressFraction, 0.5)
        station.currentProgress = 5
        XCTAssertEqual(station.progressFraction, 1)
    }

    func testProgressFractionIsZeroForZeroLengthCycle() {
        var station = Station(id: "s", name: "S", baseCost: 1, baseRevenue: 1, processingTimeInSeconds: 0)
        station.currentProgress = 1
        XCTAssertEqual(station.progressFraction, 0)
    }

    func testStartingLineupOwnsOnlyTheFirstStation() {
        let lineup = Station.startingLineup
        XCTAssertFalse(lineup.isEmpty)
        XCTAssertTrue(lineup[0].isOwned)
        XCTAssertTrue(lineup.dropFirst().allSatisfy { !$0.isOwned })
        XCTAssertEqual(Set(lineup.map(\.id)).count, lineup.count, "Station IDs must be unique")
        XCTAssertEqual(lineup.map(\.baseCost), lineup.map(\.baseCost).sorted(), "Lineup should be cheapest first")
    }
}

final class OfflineEarningsTests: XCTestCase {
    func testWasCappedAtMaxOfflineDuration() {
        XCTAssertTrue(OfflineEarnings(earnedAmount: 1, timeAway: GameMath.maxOfflineDuration).wasCapped)
        XCTAssertFalse(OfflineEarnings(earnedAmount: 1, timeAway: 60).wasCapped)
    }
}
