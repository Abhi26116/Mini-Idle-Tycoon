import SwiftUI

/// "Sell your studio" sheet: explains the prestige trade-off and, when
/// investors are available, lets the player reset for a permanent bonus.
struct PrestigeView: View {
    let investors: Int
    let claimableInvestors: Int
    let lifetimeCoins: Double
    let onSell: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isConfirming = false

    var body: some View {
        // Scrolls so nothing gets truncated at the medium detent.
        ScrollView {
            content
                .padding(24)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .confirmationDialog("Sell your studio?", isPresented: $isConfirming, titleVisibility: .visible) {
            Button("Sell and Restart", role: .destructive) {
                onSell()
                dismiss()
            }
        } message: {
            Text("All stations, managers and coins reset. Investors, gems and any active boost are kept.")
        }
    }

    private var content: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 44))
                .foregroundStyle(.teal)

            Text("Investors")
                .font(.title.bold())

            Text("Sell your studio to attract investors. You restart from scratch, but every investor adds \(percent(GameMath.investorBonusPerInvestor)) to all profits, forever.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                statTile(title: "Now", investors: investors)
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                statTile(title: "After selling", investors: investors + claimableInvestors)
            }

            if claimableInvestors > 0 {
                Button(role: .destructive) {
                    isConfirming = true
                } label: {
                    Text("Sell Studio for \(claimableInvestors) Investor\(claimableInvestors == 1 ? "" : "s")")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Text("Earn \(coinsToNextInvestor.abbreviated) more coins to attract your next investor.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Button("Not Now") { dismiss() }
        }
    }

    private func statTile(title: String, investors: Int) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(investors)")
                .font(.title2.bold().monospacedDigit())
            Text("+\(percent(GameMath.investorMultiplier(investors: investors) - 1)) profit")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.teal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Lifetime coins still needed before one more investor becomes available.
    private var coinsToNextInvestor: Double {
        let next = Double(GameMath.totalInvestors(forLifetimeCoins: lifetimeCoins) + 1)
        return max(next * next * GameMath.investorEarningsScale - lifetimeCoins, 0)
    }

    private func percent(_ fraction: Double) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0)))
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        PrestigeView(investors: 12, claimableInvestors: 30, lifetimeCoins: 2e9, onSell: {})
    }
}
