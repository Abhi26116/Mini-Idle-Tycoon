import SwiftUI

/// One station card: name, level, cycle progress, income rate and purchase
/// buttons. It receives precomputed state plus intent closures, so it holds
/// no game logic of its own.
struct StationRowView: View {
    let row: StationRowState
    let onRun: () -> Void
    let onUpgrade: () -> Void
    let onHireManager: () -> Void

    private var station: Station { row.station }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                runButton

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(station.name)
                            .font(.headline)
                        Spacer()
                        if station.isOwned {
                            Text("Lv \(station.currentLevel)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText(value: Double(station.currentLevel)))
                                .animation(.snappy, value: station.currentLevel)
                        }
                    }

                    ProgressView(value: station.progressFraction)
                        .tint(station.hasManager ? .green : .accentColor)

                    HStack {
                        Text(statusText)
                        Spacer()
                        if station.isOwned {
                            Text("\(row.revenuePerSecond.abbreviated)/sec")
                                .monospacedDigit()
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                upgradeButton
                if station.isOwned && !station.hasManager {
                    managerButton
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Subviews

    /// Tapping the icon starts a cycle on an idle, unmanaged station.
    private var runButton: some View {
        Button(action: onRun) {
            Image(systemName: symbolName)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(station.isOwned ? Color.accentColor : Color.gray,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!station.isOwned || station.isProducing)
        .accessibilityLabel("Run \(station.name)")
    }

    private var upgradeButton: some View {
        Button(action: onUpgrade) {
            VStack(spacing: 2) {
                Text(station.isOwned ? "Upgrade" : "Buy")
                    .font(.subheadline.bold())
                costLabel(row.upgradeCost)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!row.canAffordUpgrade)
    }

    private var managerButton: some View {
        Button(action: onHireManager) {
            VStack(spacing: 2) {
                Text("Hire Manager")
                    .font(.subheadline.bold())
                costLabel(row.managerCost)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(!row.canAffordManager)
    }

    private func costLabel(_ cost: Double) -> some View {
        Label(cost.abbreviated, systemImage: "dollarsign.circle.fill")
            .font(.caption.monospacedDigit())
    }

    // MARK: - Display Helpers

    private var statusText: String {
        if !station.isOwned { return "Not purchased" }
        if station.hasManager { return "Managed" }
        return station.isProducing ? "Working…" : "Tap the icon to run"
    }

    private var symbolName: String {
        switch station.id {
        case "landing-page": "doc.richtext"
        case "mobile-app": "iphone"
        case "saas-platform": "cloud.fill"
        case "ai-lab": "cpu"
        case "venture-fund": "banknote.fill"
        default: "building.2.fill"
        }
    }
}

#Preview {
    let lineup = Station.startingLineup
    var managed = lineup[1]
    managed.currentLevel = 12
    managed.hasManager = true
    managed.isProducing = true
    managed.currentProgress = 1.8

    return VStack(spacing: 12) {
        StationRowView(row: StationRowState(station: lineup[0], revenuePerSecond: 1,
                                            upgradeCost: 4.6, managerCost: 400,
                                            canAffordUpgrade: true, canAffordManager: false),
                       onRun: {}, onUpgrade: {}, onHireManager: {})
        StationRowView(row: StationRowState(station: managed, revenuePerSecond: 240,
                                            upgradeCost: 321, managerCost: 6_000,
                                            canAffordUpgrade: true, canAffordManager: true),
                       onRun: {}, onUpgrade: {}, onHireManager: {})
        StationRowView(row: StationRowState(station: lineup[2], revenuePerSecond: 0,
                                            upgradeCost: 720, managerCost: 72_000,
                                            canAffordUpgrade: false, canAffordManager: false),
                       onRun: {}, onUpgrade: {}, onHireManager: {})
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
