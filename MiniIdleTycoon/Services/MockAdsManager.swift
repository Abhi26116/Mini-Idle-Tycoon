import Foundation

/// Stand-in until a real ad SDK is integrated: waits briefly to simulate an
/// ad playing, then reports the configured outcome.
@MainActor
final class MockAdsManager: AdsManager {
    private let adDuration: Duration
    private let grantsReward: Bool

    /// - Parameters:
    ///   - adDuration: How long the fake ad "plays".
    ///   - grantsReward: Set to `false` to test the skipped/failed-ad path.
    nonisolated init(adDuration: Duration = .seconds(2), grantsReward: Bool = true) {
        self.adDuration = adDuration
        self.grantsReward = grantsReward
    }

    func showRewardedAd(completion: @escaping (Bool) -> Void) {
        Task {
            try? await Task.sleep(for: adDuration)
            completion(grantsReward)
        }
    }
}
