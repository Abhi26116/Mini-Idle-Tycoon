import Foundation

/// How many levels one tap of "Upgrade" buys.
enum BuyMode: String, CaseIterable, Identifiable {
    case one, ten, hundred, max

    var id: Self { self }

    /// Fixed level count, or `nil` for "as many as the player can afford".
    var fixedCount: Int? {
        switch self {
        case .one: 1
        case .ten: 10
        case .hundred: 100
        case .max: nil
        }
    }

    var label: String {
        switch self {
        case .one: "×1"
        case .ten: "×10"
        case .hundred: "×100"
        case .max: "Max"
        }
    }
}
