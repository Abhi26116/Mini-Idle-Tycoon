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

    /// How often the loop advances the simulation.
    private static let tickInterval: Duration = .milliseconds(100)

    /// Largest time step a single tick may apply. Caps catch-up after a stall
    /// or app suspension; longer gaps are handled by offline earnings.
    private static let maxTickDelta: TimeInterval = 1.0

    private var gameLoopTask: Task<Void, Never>?

    init(stations: [Station] = Station.startingLineup,
         profile: PlayerProfile = PlayerProfile()) {
        self.stations = stations
        self.profile = profile
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
            }
        }
    }

    func stopGameLoop() {
        gameLoopTask?.cancel()
        gameLoopTask = nil
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

        for index in updatedStations.indices {
            var station = updatedStations[index]
            guard station.isOwned, station.isProducing,
                  station.processingTimeInSeconds > 0 else { continue }

            station.currentProgress += deltaTime
            didChange = true

            if station.currentProgress >= station.processingTimeInSeconds {
                let revenue = GameMath.revenuePerCycle(for: station)

                if station.hasManager {
                    // Managers chain cycles back to back. Pay every cycle that
                    // completed and keep the leftover time so nothing is lost.
                    let cycles = (station.currentProgress / station.processingTimeInSeconds).rounded(.down)
                    earned += revenue * cycles
                    station.currentProgress = station.currentProgress
                        .truncatingRemainder(dividingBy: station.processingTimeInSeconds)
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
