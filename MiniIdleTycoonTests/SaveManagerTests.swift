import XCTest
@testable import MiniIdleTycoon

final class SaveManagerTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var saveManager: SaveManager!

    override func setUp() {
        super.setUp()
        suiteName = "SaveManagerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        saveManager = SaveManager(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testLoadReturnsNilForNewPlayer() {
        XCTAssertNil(saveManager.load())
    }

    func testSaveAndLoadRoundTrip() throws {
        var stations = Station.startingLineup
        stations[0].currentLevel = 7
        stations[0].hasManager = true
        stations[0].currentProgress = 0.4
        let savedAt = Date(timeIntervalSince1970: 1_700_000_000)
        saveManager.save(GameSaveData(profile: PlayerProfile(totalCoins: 1_234.5, premiumGems: 3),
                                      stations: stations,
                                      savedAt: savedAt,
                                      boostTimeRemaining: 90))

        let loaded = try XCTUnwrap(saveManager.load())
        XCTAssertEqual(loaded.profile, PlayerProfile(totalCoins: 1_234.5, premiumGems: 3))
        XCTAssertEqual(loaded.stations, stations)
        XCTAssertEqual(loaded.savedAt.timeIntervalSince1970, savedAt.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(loaded.boostTimeRemaining, 90)
    }

    func testCorruptDataLoadsAsNil() {
        defaults.set(Data("not json".utf8), forKey: "MiniIdleTycoon.gameSave")
        XCTAssertNil(saveManager.load())
    }

    func testSaveFromBeforeBoostExistedStillLoads() throws {
        // Encode a save, then strip the boost key to mimic an older app version.
        saveManager.save(GameSaveData(profile: PlayerProfile(totalCoins: 5),
                                      stations: Station.startingLineup,
                                      savedAt: Date(),
                                      boostTimeRemaining: 10))
        let data = try XCTUnwrap(defaults.data(forKey: "MiniIdleTycoon.gameSave"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "boostTimeRemaining")
        defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: "MiniIdleTycoon.gameSave")

        let loaded = try XCTUnwrap(saveManager.load())
        XCTAssertNil(loaded.boostTimeRemaining)
        XCTAssertEqual(loaded.profile.totalCoins, 5)
    }
}
