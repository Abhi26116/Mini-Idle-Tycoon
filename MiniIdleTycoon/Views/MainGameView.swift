import SwiftUI

/// The single game screen: currency header on top, station cards below.
struct MainGameView: View {
    @ObservedObject var viewModel: GameEngineViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
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

            Label("\(viewModel.profile.premiumGems)", systemImage: "diamond.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.purple)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.bar)
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
