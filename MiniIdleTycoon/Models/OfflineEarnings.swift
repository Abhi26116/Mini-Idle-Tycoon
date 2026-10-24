import Foundation

/// Income credited while the app was closed; drives the "welcome back" sheet.
struct OfflineEarnings: Identifiable, Equatable {
    let id = UUID()
    let earnedAmount: Double
    /// Credited time away (already capped at `GameMath.maxOfflineDuration`).
    let timeAway: TimeInterval

    var wasCapped: Bool { timeAway >= GameMath.maxOfflineDuration }
}
