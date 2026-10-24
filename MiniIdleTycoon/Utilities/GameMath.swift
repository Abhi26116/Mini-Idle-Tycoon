import Foundation

/// Stateless balance formulas for the game economy.
///
/// Every function is pure (output depends only on input), so the live game
/// loop, offline earnings and the UI all share exactly the same numbers.
struct GameMath {
    /// Each level costs 15% more than the previous one.
    static let costGrowthRate: Double = 1.15

    /// Hiring a manager costs this many times the station's base cost.
    static let managerCostMultiplier: Double = 100

    /// Revenue multiplier while a rewarded-ad boost is running.
    static let adBoostMultiplier: Double = 2.0

    /// How long one rewarded ad's boost lasts.
    static let adBoostDuration: TimeInterval = 4 * 60 * 60

    private init() {}

    // MARK: - Costs

    /// Cost to go from `currentLevel` to `currentLevel + 1`:
    /// `baseCost × 1.15^currentLevel`.
    /// At level 0 this is simply the purchase price (`baseCost`).
    static func upgradeCost(baseCost: Double, currentLevel: Int) -> Double {
        baseCost * pow(costGrowthRate, Double(max(currentLevel, 0)))
    }

    static func upgradeCost(for station: Station) -> Double {
        upgradeCost(baseCost: station.baseCost, currentLevel: station.currentLevel)
    }

    static func managerCost(for station: Station) -> Double {
        station.baseCost * managerCostMultiplier
    }

    // MARK: - Revenue

    /// Coins produced by one completed cycle: `baseRevenue × level × multiplier`.
    /// An unbought station (level 0) earns nothing.
    /// - Parameter multiplier: Global bonus, e.g. `2.0` while an ad boost is active.
    static func revenuePerCycle(baseRevenue: Double, level: Int, multiplier: Double = 1) -> Double {
        baseRevenue * Double(max(level, 0)) * multiplier
    }

    static func revenuePerCycle(for station: Station, multiplier: Double = 1) -> Double {
        revenuePerCycle(baseRevenue: station.baseRevenue,
                        level: station.currentLevel,
                        multiplier: multiplier)
    }

    /// Average income per second, used for the "/sec" label.
    static func revenuePerSecond(for station: Station, multiplier: Double = 1) -> Double {
        guard station.processingTimeInSeconds > 0 else { return 0 }
        return revenuePerCycle(for: station, multiplier: multiplier) / station.processingTimeInSeconds
    }

    // MARK: - Production Cycles

    /// Splits accumulated production time into whole completed cycles plus the
    /// leftover progress. Shared by the live loop and offline catch-up so both
    /// pay out identically.
    static func completedCycles(progress: TimeInterval,
                                cycleDuration: TimeInterval) -> (count: Double, remainder: TimeInterval) {
        guard cycleDuration > 0, progress > 0 else { return (0, max(progress, 0)) }
        let count = (progress / cycleDuration).rounded(.down)
        return (count, progress.truncatingRemainder(dividingBy: cycleDuration))
    }

    // MARK: - Offline Progress

    /// Offline income stops accruing after this long away.
    static let maxOfflineDuration: TimeInterval = 8 * 60 * 60

    /// Time away that earns offline income. Never negative (device clock wound
    /// back) and capped at `maxOfflineDuration` (clock pushed forward, or just
    /// a long absence).
    static func creditedOfflineTime(from lastActive: Date, to now: Date) -> TimeInterval {
        min(max(now.timeIntervalSince(lastActive), 0), maxOfflineDuration)
    }
}
