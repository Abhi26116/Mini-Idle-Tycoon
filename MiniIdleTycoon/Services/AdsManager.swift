import Foundation

/// Abstraction over a rewarded-ad network. The game only talks to this
/// protocol, so a real SDK (AdMob, AppLovin, Unity Ads, …) can be plugged in
/// by writing one conforming wrapper and passing it to `GameEngineViewModel`.
@MainActor
protocol AdsManager {
    /// Presents a rewarded ad.
    ///
    /// Implementations must call `completion` exactly once, on the main actor:
    /// `true` only if the player watched long enough to earn the reward, and
    /// `false` for a skip, no-fill or load error.
    func showRewardedAd(completion: @escaping (Bool) -> Void)
}

extension AdsManager {
    /// async/await bridge over the completion-based API.
    /// - Returns: Whether the player earned the reward.
    func showRewardedAd() async -> Bool {
        await withCheckedContinuation { continuation in
            showRewardedAd { rewarded in
                continuation.resume(returning: rewarded)
            }
        }
    }
}
