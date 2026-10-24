import Foundation

/// The player's wallet.
///
/// Coins are the soft currency produced by stations; gems are the premium
/// currency (purchased or rewarded).
struct PlayerProfile: Codable, Equatable, Sendable {
    /// `Double` because idle-game balances quickly outgrow `Int`.
    var totalCoins: Double = 0
    var premiumGems: Int = 0

    func canAfford(_ cost: Double) -> Bool {
        totalCoins >= cost
    }

    /// Deducts `cost` if the player can afford it.
    /// - Returns: `false` (balance untouched) when the purchase isn't possible.
    @discardableResult
    mutating func spendCoins(_ cost: Double) -> Bool {
        guard cost >= 0, canAfford(cost) else { return false }
        totalCoins -= cost
        return true
    }

    /// Adds earnings. Non-positive (or NaN) amounts are ignored, so a bad
    /// calculation can never drain the balance.
    mutating func addCoins(_ amount: Double) {
        guard amount > 0 else { return }
        totalCoins += amount
    }
}
