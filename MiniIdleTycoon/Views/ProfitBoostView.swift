import SwiftUI

/// While a boost runs, shows the "2X Profit Boost Active" banner with a live
/// countdown; otherwise offers a rewarded ad to start one.
struct ProfitBoostView: View {
    let timeRemaining: TimeInterval
    let isShowingAd: Bool
    let onWatchAd: () -> Void

    private var multiplierText: String {
        "\(GameMath.adBoostMultiplier.formatted())X"
    }

    var body: some View {
        if timeRemaining > 0 {
            activeBanner
        } else {
            watchAdButton
        }
    }

    private var activeBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.fill")
            Text("\(multiplierText) Profit Boost Active")
                .font(.subheadline.bold())
            Spacer()
            Text(Duration.seconds(timeRemaining).formatted(.time(pattern: .hourMinuteSecond)))
                .font(.subheadline.bold().monospacedDigit())
                .contentTransition(.numericText(countsDown: true))
                .animation(.default, value: Int(timeRemaining))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing),
                    in: Capsule())
        .accessibilityElement(children: .combine)
    }

    private var watchAdButton: some View {
        Button(action: onWatchAd) {
            HStack(spacing: 8) {
                if isShowingAd {
                    ProgressView()
                        .tint(.white)
                    Text("Playing ad…")
                } else {
                    Image(systemName: "play.rectangle.fill")
                    Text("Watch Ad: \(multiplierText) Profit for \(boostDurationText)")
                }
            }
            .font(.subheadline.bold())
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.orange)
        .disabled(isShowingAd)
    }

    /// e.g. "4h".
    private var boostDurationText: String {
        Duration.seconds(GameMath.adBoostDuration)
            .formatted(.units(allowed: [.hours, .minutes], width: .narrow))
    }
}

#Preview {
    VStack(spacing: 16) {
        ProfitBoostView(timeRemaining: 3 * 3600 + 59 * 60 + 12, isShowingAd: false, onWatchAd: {})
        ProfitBoostView(timeRemaining: 0, isShowingAd: false, onWatchAd: {})
        ProfitBoostView(timeRemaining: 0, isShowingAd: true, onWatchAd: {})
    }
    .padding()
}
