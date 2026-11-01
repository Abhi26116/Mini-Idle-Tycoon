import Foundation

/// The player's wallet.
///
/// Coins are the soft currency produced by stations; gems are the premium
/// currency (purchased or rewarded).
struct PlayerProfile: Codable, Equatable, Sendable {
    /// `Double` because idle-game balances quickly outgrow `Int`.
    var totalCoins: Double = 0
    var premiumGems: Int = 0
    /// Every coin ever earned, across prestige resets. Drives how many
    /// investors the player can claim.
    var lifetimeCoins: Double = 0
    /// Investors already claimed through prestige. Each one adds
    /// `GameMath.investorBonusPerInvestor` to all revenue.
    var investors: Int = 0

    init(totalCoins: Double = 0, premiumGems: Int = 0, lifetimeCoins: Double = 0, investors: Int = 0) {
        self.totalCoins = totalCoins
        self.premiumGems = premiumGems
        self.lifetimeCoins = lifetimeCoins
        self.investors = investors
    }

    /// Investors the player could claim by prestiging right now.
    var claimableInvestors: Int {
        max(GameMath.totalInvestors(forLifetimeCoins: lifetimeCoins) - investors, 0)
    }

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
        lifetimeCoins += amount
    }
}

// MARK: - Codable

extension PlayerProfile {
    private enum CodingKeys: String, CodingKey {
        case totalCoins, premiumGems, lifetimeCoins, investors
    }

    /// Fields added after launch are optional in the save, so older saves
    /// still load instead of being discarded.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalCoins = try container.decode(Double.self, forKey: .totalCoins)
        premiumGems = try container.decode(Int.self, forKey: .premiumGems)
        // Older saves didn't track lifetime earnings; current coins are the best floor.
        lifetimeCoins = try container.decodeIfPresent(Double.self, forKey: .lifetimeCoins) ?? totalCoins
        investors = try container.decodeIfPresent(Int.self, forKey: .investors) ?? 0
    }
}
