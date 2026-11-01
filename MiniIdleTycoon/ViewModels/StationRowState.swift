import Foundation

/// Everything a station row needs to render, precomputed by the view model
/// so the view itself stays free of game logic.
struct StationRowState: Identifiable, Equatable {
    let station: Station
    let revenuePerSecond: Double
    /// Levels the upgrade button buys in the current `BuyMode`.
    let upgradeCount: Int
    /// Total cost of those `upgradeCount` levels.
    let upgradeCost: Double
    let managerCost: Double
    let canAffordUpgrade: Bool
    let canAffordManager: Bool

    var id: Station.ID { station.id }

    /// Level that next doubles this station's revenue, or `nil` when maxed.
    var nextMilestone: Int? { GameMath.nextMilestone(after: station.currentLevel) }
}
