import UIKit

/// Thin wrapper around UIKit haptics so views don't create generators inline.
@MainActor
enum Haptics {
    private static let impact = UIImpactFeedbackGenerator(style: .medium)

    /// Played when a purchase (buy, upgrade or manager) succeeds.
    static func purchaseSucceeded() {
        impact.impactOccurred()
        impact.prepare() // Warm up the Taptic Engine for the next tap.
    }
}
