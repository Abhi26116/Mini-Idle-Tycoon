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

    // MARK: - Bulk Buying

    /// Total cost of buying `count` levels in a row starting at `currentLevel`
    /// (a geometric series of `upgradeCost`). `count` of 0 or less costs nothing.
    static func bulkUpgradeCost(baseCost: Double, currentLevel: Int, count: Int) -> Double {
        guard count > 0 else { return 0 }
        let first = upgradeCost(baseCost: baseCost, currentLevel: currentLevel)
        return first * (pow(costGrowthRate, Double(count)) - 1) / (costGrowthRate - 1)
    }

    static func bulkUpgradeCost(for station: Station, count: Int) -> Double {
        bulkUpgradeCost(baseCost: station.baseCost, currentLevel: station.currentLevel, count: count)
    }

    /// Most levels `coins` can buy in a row, starting at `currentLevel`.
    static func maxAffordableLevels(baseCost: Double, currentLevel: Int, coins: Double) -> Int {
        guard baseCost > 0, coins.isFinite, coins > 0 else { return 0 }
        let first = upgradeCost(baseCost: baseCost, currentLevel: currentLevel)
        // Invert the geometric series, then nudge for floating-point error.
        let estimate = log(coins * (costGrowthRate - 1) / first + 1) / log(costGrowthRate)
        var count = max(Int(estimate.rounded(.down)), 0)
        while bulkUpgradeCost(baseCost: baseCost, currentLevel: currentLevel, count: count + 1) <= coins {
            count += 1
        }
        while count > 0, bulkUpgradeCost(baseCost: baseCost, currentLevel: currentLevel, count: count) > coins {
            count -= 1
        }
        return count
    }

    // MARK: - Milestones

    /// Each of these levels doubles a station's revenue for good.
    static let milestoneLevels: [Int] = [10, 25, 50, 100, 150, 200, 300, 400, 500]

    /// `2^(milestones reached)`: 1× below level 10, 2× from 10, 4× from 25, …
    static func milestoneMultiplier(level: Int) -> Double {
        pow(2, Double(milestoneLevels.filter { level >= $0 }.count))
    }

    /// The next milestone above `level`, or `nil` once all are reached.
    static func nextMilestone(after level: Int) -> Int? {
        milestoneLevels.first { $0 > level }
    }

    // MARK: - Prestige (Investors)

    /// Lifetime coins that earn the first investor. Investors grow with the
    /// square root of lifetime earnings: 100× the coins → 10× the investors.
    static let investorEarningsScale: Double = 1_000_000

    /// Revenue bonus per investor (+2% each).
    static let investorBonusPerInvestor: Double = 0.02

    /// Investors that `lifetimeCoins` is worth in total (claimed or not).
    static func totalInvestors(forLifetimeCoins lifetimeCoins: Double) -> Int {
        guard lifetimeCoins.isFinite, lifetimeCoins > 0 else { return 0 }
        return Int((lifetimeCoins / investorEarningsScale).squareRoot().rounded(.down))
    }

    /// Global revenue multiplier from investors: `1 + 0.02 × investors`.
    static func investorMultiplier(investors: Int) -> Double {
        1 + Double(max(investors, 0)) * investorBonusPerInvestor
    }

    // MARK: - Revenue

    /// Coins produced by one completed cycle:
    /// `baseRevenue × level × milestoneMultiplier × multiplier`.
    /// An unbought station (level 0) earns nothing.
    /// - Parameter multiplier: Global bonus, e.g. ad boost × investors.
    static func revenuePerCycle(baseRevenue: Double, level: Int, multiplier: Double = 1) -> Double {
        baseRevenue * Double(max(level, 0)) * milestoneMultiplier(level: level) * multiplier
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
