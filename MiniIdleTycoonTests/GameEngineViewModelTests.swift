import XCTest
@testable import MiniIdleTycoon

@MainActor
final class GameEngineViewModelTests: XCTestCase {
    private let accuracy = 1e-9
    private let savedAt = Date(timeIntervalSince1970: 1_700_000_000)

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var saveManager: SaveManager!
    private var engine: GameEngineViewModel?

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "GameEngineViewModelTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        saveManager = SaveManager(defaults: defaults)
    }

    override func tearDown() async throws {
        engine?.stopGameLoop()
        engine = nil
        defaults.removePersistentDomain(forName: suiteName)
        try await super.tearDown()
    }

    // MARK: - New Game

    func testNewGameStartsWithStartingLineup() {
        let engine = makeEngine()
        XCTAssertEqual(engine.stations, Station.startingLineup)
        XCTAssertEqual(engine.profile.totalCoins, 0)
        XCTAssertFalse(engine.isBoostActive)
    }

    func testFirstOfflineCalculationOnNewGamePaysNothing() {
        let engine = makeEngine()
        let result = engine.calculateOfflineEarnings(now: savedAt)
        XCTAssertEqual(result.earnedAmount, 0)
        XCTAssertEqual(result.timeAway, 0)
    }

    // MARK: - Tick

    func testIdleUnmanagedStationDoesNotProgress() {
        let engine = makeEngine(stations: [station()])
        engine.tick(deltaTime: 5)
        XCTAssertEqual(engine.stations[0].currentProgress, 0)
        XCTAssertEqual(engine.profile.totalCoins, 0)
    }

    func testUnmanagedStationPaysOnceThenStops() {
        let engine = makeEngine(stations: [station(baseRevenue: 3, processingTime: 1, level: 2)])
        engine.startProduction(for: "s")
        XCTAssertTrue(engine.stations[0].isProducing)

        engine.tick(deltaTime: 2.5)

        // One cycle only, even though 2.5 cycles' worth of time passed.
        XCTAssertEqual(engine.profile.totalCoins, 6, accuracy: accuracy)
        XCTAssertFalse(engine.stations[0].isProducing)
        XCTAssertEqual(engine.stations[0].currentProgress, 0)
    }

    func testPartialCycleKeepsProgressWithoutPaying() {
        let engine = makeEngine(stations: [station(processingTime: 2, level: 1)])
        engine.startProduction(for: "s")
        engine.tick(deltaTime: 0.5)
        XCTAssertEqual(engine.stations[0].currentProgress, 0.5, accuracy: accuracy)
        XCTAssertEqual(engine.profile.totalCoins, 0)
    }

    func testManagedStationChainsCyclesAndKeepsRemainder() {
        let engine = makeEngine(stations: [station(baseRevenue: 1, processingTime: 1, level: 1, hasManager: true)])
        engine.tick(deltaTime: 2.5)
        XCTAssertEqual(engine.profile.totalCoins, 2, accuracy: accuracy)
        XCTAssertEqual(engine.stations[0].currentProgress, 0.5, accuracy: accuracy)
        XCTAssertTrue(engine.stations[0].isProducing)
    }

    func testUnownedStationNeverProduces() {
        let engine = makeEngine(stations: [station(level: 0)])
        engine.startProduction(for: "s")
        engine.tick(deltaTime: 10)
        XCTAssertFalse(engine.stations[0].isProducing)
        XCTAssertEqual(engine.profile.totalCoins, 0)
    }

    func testNonPositiveDeltaIsIgnored() {
        let engine = makeEngine(stations: [station(level: 1, hasManager: true)])
        engine.tick(deltaTime: 0)
        engine.tick(deltaTime: -1)
        XCTAssertEqual(engine.stations[0].currentProgress, 0)
    }

    // MARK: - Purchases

    func testUpgradeStationDeductsCostAndRaisesLevel() {
        let engine = makeEngine(stations: [station(baseCost: 4, level: 1)], coins: 100)
        XCTAssertTrue(engine.upgradeStation(id: "s"))
        XCTAssertEqual(engine.stations[0].currentLevel, 2)
        XCTAssertEqual(engine.profile.totalCoins, 100 - 4.6, accuracy: accuracy)
    }

    func testBuyingUnownedStationCostsBaseCost() {
        let engine = makeEngine(stations: [station(baseCost: 60, level: 0)], coins: 60)
        XCTAssertTrue(engine.upgradeStation(id: "s"))
        XCTAssertTrue(engine.stations[0].isOwned)
        XCTAssertEqual(engine.profile.totalCoins, 0, accuracy: accuracy)
    }

    func testUpgradeFailsWhenTooExpensive() {
        let engine = makeEngine(stations: [station(baseCost: 60, level: 0)], coins: 59)
        XCTAssertFalse(engine.upgradeStation(id: "s"))
        XCTAssertEqual(engine.stations[0].currentLevel, 0)
        XCTAssertEqual(engine.profile.totalCoins, 59)
    }

    func testUpgradeUnknownStationFails() {
        let engine = makeEngine(coins: 1_000)
        XCTAssertFalse(engine.upgradeStation(id: "missing"))
    }

    func testHireManagerStartsProduction() {
        let engine = makeEngine(stations: [station(baseCost: 4, level: 1)], coins: 500)
        XCTAssertTrue(engine.hireManager(for: "s"))
        XCTAssertTrue(engine.stations[0].hasManager)
        XCTAssertTrue(engine.stations[0].isProducing)
        XCTAssertEqual(engine.profile.totalCoins, 100, accuracy: accuracy)
    }

    func testCannotHireManagerTwiceOrForUnownedStation() {
        let engine = makeEngine(stations: [station(id: "a", baseCost: 1, level: 1),
                                           station(id: "b", baseCost: 1, level: 0)],
                                coins: 1_000)
        XCTAssertTrue(engine.hireManager(for: "a"))
        XCTAssertFalse(engine.hireManager(for: "a"))
        XCTAssertFalse(engine.hireManager(for: "b"))
        XCTAssertEqual(engine.profile.totalCoins, 900, accuracy: accuracy)
    }

    func testCannotHireManagerWithoutFunds() {
        let engine = makeEngine(stations: [station(baseCost: 4, level: 1)], coins: 399)
        XCTAssertFalse(engine.hireManager(for: "s"))
        XCTAssertFalse(engine.stations[0].hasManager)
    }

    // MARK: - Boost

    func testBoostDoublesLiveRevenue() {
        let engine = makeEngine(stations: [station(baseRevenue: 5, processingTime: 1, level: 1, hasManager: true)])
        engine.activateGlobalBoost()
        XCTAssertTrue(engine.isBoostActive)
        XCTAssertEqual(engine.boostTimeRemaining, GameMath.adBoostDuration)
        XCTAssertEqual(engine.revenueMultiplier, 2)

        engine.tick(deltaTime: 1)
        XCTAssertEqual(engine.profile.totalCoins, 10, accuracy: accuracy)
        XCTAssertEqual(engine.stationRows[0].revenuePerSecond, 10, accuracy: accuracy)
    }

    func testWatchingRewardedAdActivatesBoost() async {
        let engine = makeEngine(ads: MockAdsManager(adDuration: .zero, grantsReward: true))
        await engine.watchAdForBoost()
        XCTAssertTrue(engine.isBoostActive)
        XCTAssertFalse(engine.isShowingAd)
    }

    func testSkippedAdGivesNoBoost() async {
        let engine = makeEngine(ads: MockAdsManager(adDuration: .zero, grantsReward: false))
        await engine.watchAdForBoost()
        XCTAssertFalse(engine.isBoostActive)
        XCTAssertFalse(engine.isShowingAd)
    }

    // MARK: - Offline Earnings

    func testOfflinePaysManagedStationsOnly() {
        let engine = makeEngine(stations: [station(id: "managed", baseRevenue: 2, processingTime: 1,
                                                   level: 1, hasManager: true),
                                           station(id: "manual", baseRevenue: 100, processingTime: 1, level: 1)])
        let result = engine.calculateOfflineEarnings(now: savedAt.addingTimeInterval(10))
        XCTAssertEqual(result.earnedAmount, 20, accuracy: accuracy)
        XCTAssertEqual(result.timeAway, 10, accuracy: accuracy)
        XCTAssertEqual(engine.profile.totalCoins, 20, accuracy: accuracy)
    }

    func testOfflineKeepsPartialCycleProgress() {
        let engine = makeEngine(stations: [station(baseRevenue: 1, processingTime: 3, level: 1, hasManager: true)])
        engine.calculateOfflineEarnings(now: savedAt.addingTimeInterval(10))
        XCTAssertEqual(engine.profile.totalCoins, 3, accuracy: accuracy)
        XCTAssertEqual(engine.stations[0].currentProgress, 1, accuracy: accuracy)
    }

    func testOfflineTimeIsCapped() {
        let engine = makeEngine(stations: [station(baseRevenue: 1, processingTime: 1, level: 1, hasManager: true)])
        let result = engine.calculateOfflineEarnings(now: savedAt.addingTimeInterval(24 * 3_600))
        XCTAssertEqual(result.timeAway, GameMath.maxOfflineDuration)
        XCTAssertEqual(result.earnedAmount, GameMath.maxOfflineDuration, accuracy: accuracy)
    }

    func testWindingClockBackPaysNothingAndKeepsBaseline() {
        let engine = makeEngine(stations: [station(baseRevenue: 1, processingTime: 1, level: 1, hasManager: true)])
        XCTAssertEqual(engine.calculateOfflineEarnings(now: savedAt.addingTimeInterval(-100)).earnedAmount, 0)

        // The baseline stayed at `savedAt`, so the real 10s away still counts once.
        XCTAssertEqual(engine.calculateOfflineEarnings(now: savedAt.addingTimeInterval(10)).earnedAmount,
                       10, accuracy: accuracy)
    }

    func testSameOfflineTimeIsNeverPaidTwice() {
        let engine = makeEngine(stations: [station(baseRevenue: 1, processingTime: 1, level: 1, hasManager: true)])
        let now = savedAt.addingTimeInterval(10)
        engine.calculateOfflineEarnings(now: now)
        XCTAssertEqual(engine.calculateOfflineEarnings(now: now).earnedAmount, 0)
        XCTAssertEqual(engine.profile.totalCoins, 10, accuracy: accuracy)
    }

    func testOfflineBoostAppliesOnlyWhileItLasts() {
        let engine = makeEngine(stations: [station(baseRevenue: 1, processingTime: 1, level: 1, hasManager: true)],
                                boost: 5)
        let result = engine.calculateOfflineEarnings(now: savedAt.addingTimeInterval(10))
        // 5s at 2× plus 5s at 1×.
        XCTAssertEqual(result.earnedAmount, 15, accuracy: accuracy)
        XCTAssertEqual(engine.boostTimeRemaining, 0, accuracy: accuracy)
    }

    func testOfflineIsZeroWhileGameLoopRuns() {
        let engine = makeEngine(stations: [station(level: 1, hasManager: true)])
        engine.startGameLoop()
        XCTAssertEqual(engine.calculateOfflineEarnings(now: savedAt.addingTimeInterval(3_600)).earnedAmount, 0)
    }

    func testReturningWithEarningsShowsWelcomeBackSheet() {
        let engine = makeEngine(stations: [station(level: 1, hasManager: true)], savedAt: Date().addingTimeInterval(-60))
        let result = engine.handleAppDidBecomeActive()
        XCTAssertGreaterThan(result.earnedAmount, 0)
        XCTAssertEqual(engine.offlineEarnings?.earnedAmount, result.earnedAmount)
    }

    // MARK: - Persistence

    func testSaveGameRestoresIntoNewEngine() {
        let engine = makeEngine(stations: [station(baseCost: 4, level: 1)], coins: 100)
        engine.upgradeStation(id: "s")
        engine.activateGlobalBoost()
        engine.saveGame()

        let restored = GameEngineViewModel(saveManager: saveManager)
        XCTAssertEqual(restored.stations, engine.stations)
        XCTAssertEqual(restored.profile, engine.profile)
        XCTAssertEqual(restored.boostTimeRemaining, GameMath.adBoostDuration)
    }

    func testEnteringBackgroundSaves() {
        let engine = makeEngine(stations: [station(baseCost: 4, level: 1)], coins: 100)
        engine.upgradeStation(id: "s")
        engine.handleAppDidEnterBackground()
        XCTAssertEqual(saveManager.load()?.stations.first?.currentLevel, 2)
    }

    // MARK: - Helpers

    /// Builds an engine. Passing `stations` seeds a save first, so the engine
    /// loads that exact state; omitting it starts a brand-new game.
    private func makeEngine(stations: [Station]? = nil,
                            coins: Double = 0,
                            boost: TimeInterval? = nil,
                            savedAt: Date? = nil,
                            ads: any AdsManager = MockAdsManager(adDuration: .zero)) -> GameEngineViewModel {
        if let stations {
            saveManager.save(GameSaveData(profile: PlayerProfile(totalCoins: coins),
                                          stations: stations,
                                          savedAt: savedAt ?? self.savedAt,
                                          boostTimeRemaining: boost))
        }
        let engine = GameEngineViewModel(saveManager: saveManager, adsManager: ads)
        self.engine = engine
        return engine
    }

    private func station(id: String = "s",
                         baseCost: Double = 1,
                         baseRevenue: Double = 1,
                         processingTime: TimeInterval = 1,
                         level: Int = 1,
                         hasManager: Bool = false) -> Station {
        Station(id: id, name: id,
                baseCost: baseCost, baseRevenue: baseRevenue,
                processingTimeInSeconds: processingTime,
                currentLevel: level, hasManager: hasManager,
                isProducing: hasManager)
    }
}
