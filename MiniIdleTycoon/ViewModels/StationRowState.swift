import Foundation

/// Everything a station row needs to render, precomputed by the view model
/// so the view itself stays free of game logic.
struct StationRowState: Identifiable, Equatable {
    let station: Station
    let revenuePerSecond: Double
    let upgradeCost: Double
    let managerCost: Double
    let canAffordUpgrade: Bool
    let canAffordManager: Bool

    var id: Station.ID { station.id }
}
