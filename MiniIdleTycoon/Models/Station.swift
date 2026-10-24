import Foundation

/// A single revenue-generating unit of the Startup Studio (e.g. "Landing Page").
///
/// `Station` only holds state. Every balance formula (costs, revenue) lives in
/// `GameMath`, so the economy can be tuned and tested in one place.
struct Station: Identifiable, Codable, Hashable, Sendable {
    /// Stable identifier such as `"landing-page"`. A fixed string rather than a
    /// random `UUID`, so saved games keep matching their station definitions
    /// across app updates.
    let id: String
    let name: String
    /// Price of level 1. Later levels cost `baseCost × 1.15^currentLevel`.
    let baseCost: Double
    /// Coins earned per completed cycle at level 1.
    let baseRevenue: Double
    /// How long one production cycle takes.
    let processingTimeInSeconds: TimeInterval
    /// `0` means the station hasn't been bought yet.
    var currentLevel: Int = 0
    /// When `true`, cycles restart automatically and keep earning offline.
    var hasManager: Bool = false

    var isOwned: Bool { currentLevel > 0 }
}

// MARK: - Starting Lineup

extension Station {
    /// The stations a brand-new game starts with, cheapest first.
    /// The first one is already owned so the player can start earning right away.
    /// Tweak these numbers to rebalance the early game.
    static let startingLineup: [Station] = [
        Station(id: "landing-page", name: "Landing Page",
                baseCost: 4, baseRevenue: 1,
                processingTimeInSeconds: 1, currentLevel: 1),
        Station(id: "mobile-app", name: "Mobile App",
                baseCost: 60, baseRevenue: 60,
                processingTimeInSeconds: 3),
        Station(id: "saas-platform", name: "SaaS Platform",
                baseCost: 720, baseRevenue: 540,
                processingTimeInSeconds: 6),
        Station(id: "ai-lab", name: "AI Lab",
                baseCost: 8_640, baseRevenue: 4_320,
                processingTimeInSeconds: 12),
        Station(id: "venture-fund", name: "Venture Fund",
                baseCost: 103_680, baseRevenue: 51_840,
                processingTimeInSeconds: 24),
    ]
}
