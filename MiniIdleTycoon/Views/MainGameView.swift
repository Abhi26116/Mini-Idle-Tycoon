import SwiftUI

/// The single game screen: currency header on top, station cards below.
struct MainGameView: View {
    @ObservedObject var viewModel: GameEngineViewModel
    @State private var isShowingPrestige = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Picker("Buy amount", selection: $viewModel.buyMode) {
                    ForEach(BuyMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                ForEach(viewModel.stationRows) { row in
                    StationRowView(
                        row: row,
                        onRun: { viewModel.startProduction(for: row.id) },
                        onUpgrade: {
                            if viewModel.upgradeStation(id: row.id) {
                                Haptics.purchaseSucceeded()
                            }
                        },
                        onHireManager: {
                            if viewModel.hireManager(for: row.id) {
                                Haptics.purchaseSucceeded()
                            }
                        }
                    )
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .top, spacing: 0) {
            header
        }
        .sheet(item: $viewModel.offlineEarnings) { earnings in
            OfflineEarningsView(earnings: earnings)
        }
        .sheet(isPresented: $isShowingPrestige) {
            PrestigeView(investors: viewModel.profile.investors,
                         claimableInvestors: viewModel.claimableInvestors,
                         lifetimeCoins: viewModel.profile.lifetimeCoins,
                         onSell: {
                             if viewModel.prestige() > 0 {
                                 Haptics.purchaseSucceeded()
                             }
                         })
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Startup Studio")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundStyle(.yellow)
                Text(viewModel.profile.totalCoins.abbreviated)
                    .contentTransition(.numericText(value: viewModel.profile.totalCoins))
                    .animation(.snappy, value: viewModel.profile.totalCoins)
            }
            .font(.system(size: 40, weight: .bold, design: .rounded))
            .monospacedDigit()

            HStack(spacing: 16) {
                Label("\(viewModel.profile.premiumGems)", systemImage: "diamond.fill")
                    .foregroundStyle(.purple)

                Button {
                    isShowingPrestige = true
                } label: {
                    Label(investorsText, systemImage: "person.3.fill")
                        .foregroundStyle(.teal)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows investors and the option to sell your studio")
            }
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()

            ProfitBoostView(
                timeRemaining: viewModel.boostTimeRemaining,
                isShowingAd: viewModel.isShowingAd,
                onWatchAd: { Task { await viewModel.watchAdForBoost() } }
            )
            .padding(.horizontal)
            .padding(.top, 8)
            .animation(.snappy, value: viewModel.isBoostActive)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.bar)
    }

    /// e.g. "12" or "12 (+30)" when more investors can be claimed.
    private var investorsText: String {
        let claimable = viewModel.claimableInvestors
        let owned = "\(viewModel.profile.investors)"
        return claimable > 0 ? "\(owned) (+\(claimable))" : owned
    }
}

#Preview {
    // Separate defaults suite so the preview never touches a real save.
    let viewModel = GameEngineViewModel(
        saveManager: SaveManager(defaults: UserDefaults(suiteName: "preview") ?? .standard)
    )
    return MainGameView(viewModel: viewModel)
        .onAppear { viewModel.startGameLoop() }
}
