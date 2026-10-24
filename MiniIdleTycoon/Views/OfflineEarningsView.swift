import SwiftUI

/// "Welcome back" sheet summarizing what managers earned while the app was closed.
/// The coins are already credited; "Collect" just dismisses.
struct OfflineEarningsView: View {
    let earnings: OfflineEarnings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 48))
                .foregroundStyle(.indigo)

            Text("Welcome Back!")
                .font(.title.bold())

            Text("While you were away for \(formatted(earnings.timeAway)), your managers earned")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundStyle(.yellow)
                Text(earnings.earnedAmount.abbreviated)
            }
            .font(.system(size: 36, weight: .bold, design: .rounded))

            if earnings.wasCapped {
                Text("Offline earnings are capped at \(formatted(GameMath.maxOfflineDuration)).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button("Collect") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(24)
        .presentationDetents([.medium])
    }

    /// e.g. "2 hours, 13 minutes".
    private func formatted(_ interval: TimeInterval) -> String {
        Duration.seconds(interval)
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide, maximumUnitCount: 2))
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        OfflineEarningsView(earnings: OfflineEarnings(earnedAmount: 12_345,
                                                      timeAway: GameMath.maxOfflineDuration))
    }
}
