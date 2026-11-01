import XCTest
@testable import MiniIdleTycoon

/// Milestones, bulk buying and prestige (investors).
final class ProgressionMathTests: XCTestCase {
    private let accuracy = 1e-6

    // MARK: - Milestones

    func testMilestoneMultiplierDoublesAtEachThreshold() {
        XCTAssertEqual(GameMath.milestoneMultiplier(level: 9), 1)
        XCTAssertEqual(GameMath.milestoneMultiplier(level: 10), 2)
        XCTAssertEqual(GameMath.milestoneMultiplier(level: 24), 2)
        XCTAssertEqual(GameMath.milestoneMultiplier(level: 25), 4)
        XCTAssertEqual(GameMath.milestoneMultiplier(level: 500), pow(2, Double(GameMath.milestoneLevels.count)))
    }

    func testRevenueIncludesMilestoneBonus() {
        // Level 10 → 10 × 2.
        XCTAssertEqual(GameMath.revenuePerCycle(baseRevenue: 1, level: 10), 20, accuracy: accuracy)
    }

    func testNextMilestone() {
        XCTAssertEqual(GameMath.nextMilestone(after: 0), 10)
        XCTAssertEqual(GameMath.nextMilestone(after: 10), 25)
        XCTAssertNil(GameMath.nextMilestone(after: 500))
    }

    // MARK: - Bulk Buying

    func testBulkCostEqualsSumOfSingleUpgrades() {
        let summed = (5..<15).reduce(0) { $0 + GameMath.upgradeCost(baseCost: 4, currentLevel: $1) }
        XCTAssertEqual(GameMath.bulkUpgradeCost(baseCost: 4, currentLevel: 5, count: 10), summed, accuracy: accuracy)
    }

    func testBulkCostOfZeroLevelsIsFree() {
        XCTAssertEqual(GameMath.bulkUpgradeCost(baseCost: 4, currentLevel: 5, count: 0), 0)
    }

    func testMaxAffordableLevelsIsExact() {
        let cost3 = GameMath.bulkUpgradeCost(baseCost: 4, currentLevel: 1, count: 3)
        XCTAssertEqual(GameMath.maxAffordableLevels(baseCost: 4, currentLevel: 1, coins: cost3), 3)
        XCTAssertEqual(GameMath.maxAffordableLevels(baseCost: 4, currentLevel: 1, coins: cost3 - 0.01), 2)
    }

    func testMaxAffordableLevelsWithNoCoins() {
        XCTAssertEqual(GameMath.maxAffordableLevels(baseCost: 4, currentLevel: 1, coins: 0), 0)
        XCTAssertEqual(GameMath.maxAffordableLevels(baseCost: 4, currentLevel: 1, coins: 4), 0)
        XCTAssertEqual(GameMath.maxAffordableLevels(baseCost: 4, currentLevel: 1, coins: .infinity), 0)
    }

    // MARK: - Investors

    func testInvestorsGrowWithSquareRootOfLifetimeCoins() {
        XCTAssertEqual(GameMath.totalInvestors(forLifetimeCoins: 0), 0)
        XCTAssertEqual(GameMath.totalInvestors(forLifetimeCoins: 999_999), 0)
        XCTAssertEqual(GameMath.totalInvestors(forLifetimeCoins: 1_000_000), 1)
        XCTAssertEqual(GameMath.totalInvestors(forLifetimeCoins: 100_000_000), 10)
        XCTAssertEqual(GameMath.totalInvestors(forLifetimeCoins: .nan), 0)
    }

    func testInvestorMultiplier() {
        XCTAssertEqual(GameMath.investorMultiplier(investors: 0), 1)
        XCTAssertEqual(GameMath.investorMultiplier(investors: 50), 2, accuracy: accuracy)
    }

    func testClaimableInvestorsSubtractsClaimed() {
        XCTAssertEqual(PlayerProfile(lifetimeCoins: 100_000_000, investors: 4).claimableInvestors, 6)
        XCTAssertEqual(PlayerProfile(lifetimeCoins: 100_000_000, investors: 12).claimableInvestors, 0)
    }

    func testAddCoinsAlsoCountsTowardLifetime() {
        var profile = PlayerProfile()
        profile.addCoins(10)
        profile.spendCoins(4)
        XCTAssertEqual(profile.totalCoins, 6)
        XCTAssertEqual(profile.lifetimeCoins, 10)
    }

    func testProfileFromBeforePrestigeExistedStillDecodes() throws {
        let json = Data(#"{"totalCoins": 500, "premiumGems": 2}"#.utf8)
        let profile = try JSONDecoder().decode(PlayerProfile.self, from: json)
        XCTAssertEqual(profile.totalCoins, 500)
        XCTAssertEqual(profile.premiumGems, 2)
        XCTAssertEqual(profile.lifetimeCoins, 500)
        XCTAssertEqual(profile.investors, 0)
    }
}

@MainActor
final class ProgressionEngineTests: XCTestCase {
    private let accuracy = 1e-6
    private let savedAt = Date(timeIntervalSince1970: 1_700_000_000)

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var saveManager: SaveManager!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "ProgressionEngineTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        saveManager = SaveManager(defaults: defaults)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        try await super.tearDown()
    }

    // MARK: - Bulk Buying

    func testBuyTenIsAllOrNothing() {
        let engine = makeEngine(coins: 50)
        engine.buyMode = .ten
        let cost = GameMath.bulkUpgradeCost(baseCost: 4, currentLevel: 1, count: 10)
        XCTAssertGreaterThan(cost, 50)
        XCTAssertFalse(engine.upgradeStation(id: "s"))
        XCTAssertEqual(engine.stations[0].currentLevel, 1)
    }

    func testBuyTenRaisesTenLevels() {
        let cost = GameMath.bulkUpgradeCost(baseCost: 4, currentLevel: 1, count: 10)
        let engine = makeEngine(coins: cost + 1)
        engine.buyMode = .ten
        XCTAssertTrue(engine.upgradeStation(id: "s"))
        XCTAssertEqual(engine.stations[0].currentLevel, 11)
        XCTAssertEqual(engine.profile.totalCoins, 1, accuracy: accuracy)
    }

    func testBuyMaxBuysEverythingAffordable() {
        let engine = makeEngine(coins: GameMath.bulkUpgradeCost(baseCost: 4, currentLevel: 1, count: 7) + 1)
        engine.buyMode = .max
        XCTAssertEqual(engine.stationRows[0].upgradeCount, 7)
        XCTAssertTrue(engine.upgradeStation(id: "s"))
        XCTAssertEqual(engine.stations[0].currentLevel, 8)
    }

    func testBuyMaxWithNothingAffordableShowsOneLevelAndFails() {
        let engine = makeEngine(coins: 1)
        engine.buyMode = .max
        XCTAssertEqual(engine.stationRows[0].upgradeCount, 1)
        XCTAssertFalse(engine.stationRows[0].canAffordUpgrade)
        XCTAssertFalse(engine.upgradeStation(id: "s"))
    }

    // MARK: - Investors & Prestige

    func testInvestorsBoostLiveRevenue() {
        let engine = makeEngine(investors: 50, hasManager: true)
        engine.tick(deltaTime: 1)
        XCTAssertEqual(engine.profile.totalCoins, 2, accuracy: accuracy)
    }

    func testInvestorsBoostOfflineRevenue() {
        let engine = makeEngine(investors: 50, hasManager: true)
        let result = engine.calculateOfflineEarnings(now: savedAt.addingTimeInterval(10))
        XCTAssertEqual(result.earnedAmount, 20, accuracy: accuracy)
    }

    func testPrestigeWithNoInvestorsDoesNothing() {
        let engine = makeEngine(coins: 500, lifetimeCoins: 500)
        XCTAssertEqual(engine.prestige(), 0)
        XCTAssertEqual(engine.profile.totalCoins, 500)
        XCTAssertEqual(engine.stations[0].currentLevel, 1)
    }

    func testPrestigeResetsRunAndKeepsInvestors() {
        let engine = makeEngine(coins: 5_000, lifetimeCoins: 100_000_000, investors: 4, gems: 3, level: 40)
        engine.activateGlobalBoost()

        XCTAssertEqual(engine.prestige(), 6)

        XCTAssertEqual(engine.profile.investors, 10)
        XCTAssertEqual(engine.profile.totalCoins, 0)
        XCTAssertEqual(engine.profile.lifetimeCoins, 100_000_000)
        XCTAssertEqual(engine.profile.premiumGems, 3)
        XCTAssertEqual(engine.stations, Station.startingLineup)
        XCTAssertTrue(engine.isBoostActive)
        XCTAssertEqual(engine.claimableInvestors, 0)
    }

    func testPrestigeIsSavedImmediately() {
        let engine = makeEngine(lifetimeCoins: 4_000_000)
        engine.prestige()
        let saved = saveManager.load()
        XCTAssertEqual(saved?.profile.investors, 2)
        XCTAssertEqual(saved?.stations, Station.startingLineup)
    }

    // MARK: - Helpers

    private func makeEngine(coins: Double = 0,
                            lifetimeCoins: Double = 0,
                            investors: Int = 0,
                            gems: Int = 0,
                            level: Int = 1,
                            hasManager: Bool = false) -> GameEngineViewModel {
        let station = Station(id: "s", name: "S", baseCost: 4, baseRevenue: 1,
                              processingTimeInSeconds: 1, currentLevel: level,
                              hasManager: hasManager, isProducing: hasManager)
        saveManager.save(GameSaveData(profile: PlayerProfile(totalCoins: coins, premiumGems: gems,
                                                             lifetimeCoins: lifetimeCoins, investors: investors),
                                      stations: [station],
                                      savedAt: savedAt,
                                      boostTimeRemaining: nil))
        return GameEngineViewModel(saveManager: saveManager, adsManager: MockAdsManager(adDuration: .zero))
    }
}
