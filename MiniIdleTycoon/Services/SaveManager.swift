import Foundation
import os

/// Snapshot of everything needed to restore a game.
struct GameSaveData: Codable {
    var profile: PlayerProfile
    var stations: [Station]
    /// Wall-clock moment this snapshot is accurate as of; the baseline for
    /// offline earnings. `Date` is an absolute (UTC) instant, so time zones
    /// and daylight saving never affect it.
    var savedAt: Date
}

/// Persists the game to `UserDefaults` as a single JSON blob, so the profile,
/// stations and timestamp are always written together and can't drift apart.
struct SaveManager {
    private static let saveKey = "MiniIdleTycoon.gameSave"
    private static let logger = Logger(subsystem: "MiniIdleTycoon", category: "SaveManager")

    private let defaults: UserDefaults

    /// - Parameter defaults: Pass a custom suite to isolate tests and previews.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(_ data: GameSaveData) {
        do {
            let encoded = try JSONEncoder().encode(data)
            defaults.set(encoded, forKey: Self.saveKey)
        } catch {
            Self.logger.error("Failed to encode save: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// - Returns: The last save, or `nil` for a new player (or unreadable data).
    func load() -> GameSaveData? {
        guard let data = defaults.data(forKey: Self.saveKey) else { return nil }
        do {
            return try JSONDecoder().decode(GameSaveData.self, from: data)
        } catch {
            Self.logger.error("Failed to decode save, starting fresh: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
