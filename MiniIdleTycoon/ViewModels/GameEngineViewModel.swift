import Combine
import Foundation

/// Owns all live game state and runs the simulation.
///
/// Thread safety: the class is `@MainActor`, so every read and write of
/// `stations` and `profile` (from the game loop *and* from player actions)
/// is serialized on the main actor. No locks needed, and SwiftUI always
/// observes changes on the main thread.
@MainActor
final class GameEngineViewModel: ObservableObject {
    @Published private(set) var stations: [Station]
    @Published private(set) var profile: PlayerProfile

    /// Set when the player returns with offline income. Settable so the
    /// sheet can clear it on dismiss.
    @Published var offlineEarnings: OfflineEarnings?

    /// Seconds left on the rewarded-ad profit boost; `0` when inactive.
    /// Stored as a duration rather than an end date, so changing the device
    /// clock can't stretch the boost.
    @Published private(set) var boostTimeRemaining: TimeInterval = 0

    /// `true` while a rewarded ad is on screen.
    @Published private(set) var isShowingAd = false

    var isBoostActive: Bool { boostTimeRemaining > 0 }

    /// Applied to every station's revenue: 2× while boosted, otherwise 1×.
    var revenueMultiplier: Double {
        isBoostActive ? GameMath.adBoostMultiplier : 1
    }

    /// How often the loop advances the simulation.
    private static let tickInterval: Duration = .milliseconds(100)

    /// Largest time step a single tick may apply. Caps catch-up after a stall
    /// or app suspension; longer gaps are handled by offline earnings.
    private static let maxTickDelta: TimeInterval = 1.0

    /// Saves periodically while playing, so a crash (or hitting Stop in Xcode)
    /// loses at most this much progress.
    private static let autosaveInterval: TimeInterval = 30

    /// The boost countdown only needs one-second resolution.
    private static let boostTimerInterval: Duration = .seconds(1)

    private let saveManager: SaveManager
    private let adsManager: any AdsManager
    private var gameLoopTask: Task<Void, Never>?
    private var boostTimerTask: Task<Void, Never>?
    private var timeSinceAutosave: TimeInterval = 0

    /// Wall-clock moment the current state is accurate as of: the baseline for
    /// offline earnings. It only ever moves forward, so winding the device
    /// clock back can't be used to collect the same offline time twice.
    private var stateTimestamp: Date?

    /// Restores the last save, or starts a new game if there is none.
    /// - Parameter adsManager: Swap `MockAdsManager` for a real SDK wrapper.
    init(saveManager: SaveManager = SaveManager(),
         adsManager: any AdsManager = MockAdsManager()) {
        self.saveManager = saveManager
        self.adsManager = adsManager

        if let save = saveManager.load() {
            stations = save.stations
            profile = save.profile
            stateTimestamp = save.savedAt
            boostTimeRemaining = save.boostTimeRemaining ?? 0
        } else {
            stations = Station.startingLineup
            profile = PlayerProfile()
        }
    }

    // MARK: - Presentation

    var stationRows: [StationRowState] {
        let multiplier = revenueMultiplier
        return stations.map { station in
            let upgradeCost = GameMath.upgradeCost(for: station)
            let managerCost = GameMath.managerCost(for: station)
            return StationRowState(station: station,
                                   revenuePerSecond: GameMath.revenuePerSecond(for: station,
                                                                               multiplier: multiplier),
                                   upgradeCost: upgradeCost,
                                   managerCost: managerCost,
                                   canAffordUpgrade: profile.canAfford(upgradeCost),
                                   canAffordManager: profile.canAfford(managerCost))
        }
    }

    // MARK: - App Lifecycle

    /// Call when the app becomes active (launch or return from background).
    /// Credits offline earnings first, then resumes the live loop. Shows the
    /// "welcome back" sheet when anything was earned.
    @discardableResult
    func handleAppDidBecomeActive() -> (earnedAmount: Double, timeAway: TimeInterval) {
        let offline = calculateOfflineEarnings()
        if offline.earnedAmount > 0 {
            offlineEarnings = OfflineEarnings(earnedAmount: offline.earnedAmount,
                                              timeAway: offline.timeAway)
        }
        startGameLoop()
        return offline
    }

    /// Call when the app moves to the background. Stops the loop, which stamps
    /// the current time as the offline baseline, then saves.
    func handleAppDidEnterBackground() {
        stopGameLoop()
        saveGame()
    }

    // MARK: - Game Loop

    /// Starts ticking every 0.1s. Calling it while already running does nothing.
    func startGameLoop() {
        guard gameLoopTask == nil else { return }

        // Inherits main-actor isolation, so `tick` runs on the main actor.
        // `weak self` lets the view model deallocate, which also ends the loop.
        gameLoopTask = Task { [weak self] in
            let clock = ContinuousClock()
            var lastTick = clock.now

            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: Self.tickInterval)
                } catch {
                    break // Cancelled by stopGameLoop().
                }

                // Measure real elapsed time instead of assuming exactly 0.1s,
                // so sleep jitter never makes stations run slow.
                let now = clock.now
                let elapsed = min(lastTick.duration(to: now).timeInterval, Self.maxTickDelta)
                lastTick = now

                guard let self else { return }
                self.tick(deltaTime: elapsed)
                self.autosaveIfNeeded(after: elapsed)
            }
        }

        startBoostTimer()
    }

    /// Stops the game loop and the boost timer together.
    func stopGameLoop() {
        stopBoostTimer()
        guard let gameLoopTask else { return }
        gameLoopTask.cancel()
        self.gameLoopTask = nil
        // Live simulation ends here; any offline time counts from this moment.
        advanceStateTimestamp(to: Date())
    }

    /// Advances every running station by `deltaTime` seconds and pays out
    /// completed cycles. Called by the game loop; internal so tests can drive
    /// time deterministically.
    func tick(deltaTime: TimeInterval) {
        guard deltaTime > 0 else { return }

        // Mutate a local copy and publish once per tick, not once per station.
        var updatedStations = stations
        var earned: Double = 0
        var didChange = false
        let multiplier = revenueMultiplier

        for index in updatedStations.indices {
            var station = updatedStations[index]
            guard station.isOwned, station.isProducing,
                  station.processingTimeInSeconds > 0 else { continue }

            station.currentProgress += deltaTime
            didChange = true

            if station.currentProgress >= station.processingTimeInSeconds {
                let revenue = GameMath.revenuePerCycle(for: station, multiplier: multiplier)

                if station.hasManager {
                    // Managers chain cycles back to back. Pay every cycle that
                    // completed and keep the leftover time so nothing is lost.
                    let cycles = GameMath.completedCycles(progress: station.currentProgress,
                                                          cycleDuration: station.processingTimeInSeconds)
                    earned += revenue * cycles.count
                    station.currentProgress = cycles.remainder
                } else {
                    // No manager: pay out once, then wait for the next tap.
                    earned += revenue
                    station.currentProgress = 0
                    station.isProducing = false
                }
            }

            updatedStations[index] = station
        }

        if didChange {
            stations = updatedStations
        }
        if earned > 0 {
            profile.addCoins(earned)
        }
    }

    // MARK: - Offline Earnings

    /// Credits the income managed stations generated while the game wasn't
    /// running, and adds it to `totalCoins`.
    ///
    /// Anti-cheat: time away is never negative (clock wound back), is capped at
    /// `GameMath.maxOfflineDuration` (clock pushed forward), and the baseline
    /// only moves forward. Calling this while the live loop is running returns
    /// zero, so it can never pay for the same time twice.
    /// - Returns: Coins earned, and the time away that was credited (after the cap).
    @discardableResult
    func calculateOfflineEarnings(now: Date = Date()) -> (earnedAmount: Double, timeAway: TimeInterval) {
        // The live loop is already accounting for time.
        guard gameLoopTask == nil else { return (0, 0) }

        guard let lastActive = stateTimestamp else {
            // New game: nothing to catch up on yet.
            stateTimestamp = now
            return (0, 0)
        }
        advanceStateTimestamp(to: now)

        let timeAway = GameMath.creditedOfflineTime(from: lastActive, to: now)
        guard timeAway > 0 else { return (0, 0) }

        // A running boost kept ticking while away: the first `boostedTime`
        // seconds earn 2×, the rest 1×.
        let boostedTime = min(boostTimeRemaining, timeAway)
        let normalTime = timeAway - boostedTime
        boostTimeRemaining -= boostedTime

        var updatedStations = stations
        var earned: Double = 0

        for index in updatedStations.indices {
            let station = updatedStations[index]
            guard station.isOwned, station.hasManager else { continue }

            // Same cycle math as the live loop, so offline pays exactly what
            // the managers would have earned with the app open.
            let duration = station.processingTimeInSeconds
            let boosted = GameMath.completedCycles(progress: station.currentProgress + boostedTime,
                                                   cycleDuration: duration)
            let normal = GameMath.completedCycles(progress: boosted.remainder + normalTime,
                                                  cycleDuration: duration)
            let revenue = GameMath.revenuePerCycle(for: station)
            earned += revenue * (boosted.count * GameMath.adBoostMultiplier + normal.count)
            updatedStations[index].currentProgress = normal.remainder
        }

        stations = updatedStations
        if earned > 0 {
            profile.addCoins(earned)
        }
        return (earned, timeAway)
    }

    // MARK: - Persistence

    func saveGame() {
        let now = Date()
        // While the loop runs the state is live, i.e. accurate as of now.
        if gameLoopTask != nil {
            advanceStateTimestamp(to: now)
        }
        saveManager.save(GameSaveData(profile: profile,
                                      stations: stations,
                                      savedAt: stateTimestamp ?? now,
                                      boostTimeRemaining: boostTimeRemaining))
        timeSinceAutosave = 0
    }

    private func autosaveIfNeeded(after elapsed: TimeInterval) {
        timeSinceAutosave += elapsed
        guard timeSinceAutosave >= Self.autosaveInterval else { return }
        saveGame()
    }

    /// Moves the offline baseline forward, never back.
    private func advanceStateTimestamp(to date: Date) {
        stateTimestamp = max(stateTimestamp ?? date, date)
    }

    // MARK: - Monetization

    /// Plays a rewarded ad and activates the profit boost if the player earns
    /// the reward. Does nothing while an ad is showing or a boost is running.
    func watchAdForBoost() async {
        guard !isShowingAd, !isBoostActive else { return }

        isShowingAd = true
        let rewarded = await adsManager.showRewardedAd()
        isShowingAd = false

        if rewarded {
            activateGlobalBoost()
        }
    }

    /// Multiplies ALL station revenue by `GameMath.adBoostMultiplier` for
    /// `GameMath.adBoostDuration`. Activating again resets the countdown.
    func activateGlobalBoost() {
        boostTimeRemaining = GameMath.adBoostDuration
        if gameLoopTask != nil {
            startBoostTimer()
        }
    }

    /// Separate one-second timer that counts the boost down. It runs alongside
    /// the game loop and stops with it in the background; time away is
    /// deducted by `calculateOfflineEarnings()` instead.
    private func startBoostTimer() {
        guard boostTimerTask == nil, isBoostActive else { return }

        boostTimerTask = Task { [weak self] in
            let clock = ContinuousClock()
            var lastTick = clock.now

            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: Self.boostTimerInterval)
                } catch {
                    break // Cancelled by stopBoostTimer().
                }

                let now = clock.now
                let elapsed = lastTick.duration(to: now).timeInterval
                lastTick = now

                guard let self else { return }
                self.boostTimeRemaining = max(self.boostTimeRemaining - elapsed, 0)
                if !self.isBoostActive {
                    self.boostTimerTask = nil
                    return
                }
            }
        }
    }

    private func stopBoostTimer() {
        boostTimerTask?.cancel()
        boostTimerTask = nil
    }

    // MARK: - Player Actions

    /// Starts one production cycle on an owned, idle station (the player's tap).
    func startProduction(for id: Station.ID) {
        guard let index = stationIndex(for: id),
              stations[index].isOwned,
              !stations[index].isProducing else { return }

        stations[index].isProducing = true
    }

    /// Buys the station (level 0 → 1) or upgrades it one level, deducting
    /// `GameMath.upgradeCost`.
    /// - Returns: `true` on success, so the UI can fire haptics only then.
    @discardableResult
    func upgradeStation(id: Station.ID) -> Bool {
        guard let index = stationIndex(for: id) else { return false }

        let cost = GameMath.upgradeCost(for: stations[index])
        // Check first: calling a mutating method on a @Published value
        // republishes even when nothing changes.
        guard profile.canAfford(cost) else { return false }

        profile.spendCoins(cost)
        stations[index].currentLevel += 1
        return true
    }

    /// Hires a manager for an owned station. The manager starts producing
    /// immediately and keeps the station running from then on.
    /// - Returns: `true` on success.
    @discardableResult
    func hireManager(for id: Station.ID) -> Bool {
        guard let index = stationIndex(for: id),
              stations[index].isOwned,
              !stations[index].hasManager else { return false }

        let cost = GameMath.managerCost(for: stations[index])
        guard profile.canAfford(cost) else { return false }

        profile.spendCoins(cost)
        stations[index].hasManager = true
        stations[index].isProducing = true
        return true
    }

    // MARK: - Helpers

    private func stationIndex(for id: Station.ID) -> Int? {
        stations.firstIndex { $0.id == id }
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        let (seconds, attoseconds) = components
        return TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
    }
}
