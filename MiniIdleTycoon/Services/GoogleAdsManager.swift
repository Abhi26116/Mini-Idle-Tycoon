import AppTrackingTransparency
import GoogleMobileAds
import os
import UIKit
import UserMessagingPlatform

/// Rewarded ads through Google Mobile Ads (AdMob).
///
/// Call `start()` once the app is active. It runs Google's required order:
/// consent form (UMP, shown only where the law requires it) → App Tracking
/// Transparency prompt → SDK start → preload the first ad. After every ad the
/// next one is preloaded, so the boost button usually plays instantly.
@MainActor
final class GoogleAdsManager: NSObject, AdsManager {
    private static let logger = Logger(subsystem: "MiniIdleTycoon", category: "Ads")

    /// From the `REWARDED_AD_UNIT_ID` build setting, via Info.plist.
    private let adUnitID: String

    private var hasStarted = false
    private var isSDKReady = false
    private var rewardedAd: RewardedAd?
    private var isLoading = false
    /// Callers waiting for the ad currently loading.
    private var loadWaiters: [(RewardedAd?) -> Void] = []

    /// The ad on screen: its caller's completion and whether the reward was earned.
    private var pendingCompletion: ((Bool) -> Void)?
    private var didEarnReward = false

    nonisolated override init() {
        adUnitID = Bundle.main.object(forInfoDictionaryKey: "RewardedAdUnitID") as? String ?? ""
        super.init()
    }

    // MARK: - Startup

    /// Gathers consent, asks for tracking permission, starts the SDK and
    /// preloads an ad. Safe to call more than once; only the first call runs.
    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters()) { [weak self] error in
            Task { @MainActor in
                if let error {
                    // Still try: consent from an earlier launch may allow ads.
                    Self.logger.error("Consent info update failed: \(error.localizedDescription, privacy: .public)")
                }
                self?.presentConsentFormIfRequired()
            }
        }
    }

    private func presentConsentFormIfRequired() {
        ConsentForm.loadAndPresentIfRequired(from: Self.topViewController()) { [weak self] error in
            Task { @MainActor in
                if let error {
                    Self.logger.error("Consent form failed: \(error.localizedDescription, privacy: .public)")
                }
                guard ConsentInformation.shared.canRequestAds else {
                    Self.logger.info("Consent does not allow ads yet")
                    return
                }
                await self?.requestTrackingAuthorizationIfNeeded()
                self?.startSDK()
            }
        }
    }

    /// Shows the system ATT prompt once. Ads still work if the player declines;
    /// they are just not personalized with the advertising identifier.
    private func requestTrackingAuthorizationIfNeeded() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }

    private func startSDK() {
        MobileAds.shared.start { [weak self] _ in
            Task { @MainActor in
                self?.isSDKReady = true
                self?.loadAd { _ in }
            }
        }
    }

    // MARK: - Loading

    /// Loads a rewarded ad unless one is ready or already loading, then calls
    /// `completion` with the ready ad (or `nil` on failure).
    private func loadAd(completion: @escaping (RewardedAd?) -> Void) {
        if let rewardedAd {
            completion(rewardedAd)
            return
        }
        loadWaiters.append(completion)
        guard !isLoading else { return }
        isLoading = true

        RewardedAd.load(with: adUnitID, request: Request()) { [weak self] ad, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    Self.logger.error("Rewarded ad failed to load: \(error.localizedDescription, privacy: .public)")
                }
                ad?.fullScreenContentDelegate = self
                self.rewardedAd = ad
                self.isLoading = false
                let waiters = self.loadWaiters
                self.loadWaiters = []
                waiters.forEach { $0(ad) }
            }
        }
    }

    // MARK: - AdsManager

    func showRewardedAd(completion: @escaping (Bool) -> Void) {
        // Consent or the SDK isn't ready (e.g. the player declined consent).
        guard isSDKReady, ConsentInformation.shared.canRequestAds, pendingCompletion == nil else {
            completion(false)
            return
        }

        loadAd { [weak self] ad in
            guard let self, let ad, let presenter = Self.topViewController() else {
                completion(false)
                return
            }
            self.pendingCompletion = completion
            self.didEarnReward = false
            ad.present(from: presenter) { [weak self] in
                self?.didEarnReward = true
            }
        }
    }

    /// Reports the outcome exactly once, then preloads the next ad.
    private func finishPresentation(rewarded: Bool) {
        rewardedAd = nil
        let completion = pendingCompletion
        pendingCompletion = nil
        completion?(rewarded)
        loadAd { _ in }
    }

    // MARK: - Helpers

    /// The view controller currently on top, to present ads and forms from.
    private static func topViewController() -> UIViewController? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

// MARK: - FullScreenContentDelegate

extension GoogleAdsManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        // Grant the reward only after the ad closes, so the boost starts in-game.
        finishPresentation(rewarded: didEarnReward)
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Self.logger.error("Rewarded ad failed to present: \(error.localizedDescription, privacy: .public)")
        finishPresentation(rewarded: false)
    }
}
