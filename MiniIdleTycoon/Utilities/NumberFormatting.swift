import Foundation

extension Double {
    private static let suffixes = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]

    /// Compact display for idle-game numbers:
    /// `950` → "950", `4.6` → "4.6", `12_345` → "12.35K", `5.6e9` → "5.6B".
    var abbreviated: String {
        guard isFinite else { return "∞" }
        // Compare the rounded value, so 999.96 shows as "1K" rather than "1,000".
        guard abs((self * 10).rounded() / 10) >= 1_000 else {
            return formatted(.number.precision(.fractionLength(0...1)))
        }

        var tier = max(1, Int(log10(abs(self)) / 3))
        var scaled = self / pow(1_000, Double(tier))
        // Rounding can turn e.g. 999.996K into "1,000K"; use the next suffix instead.
        if abs((scaled * 100).rounded() / 100) >= 1_000 {
            tier += 1
            scaled /= 1_000
        }

        guard tier < Self.suffixes.count else {
            return formatted(.number.notation(.scientific).precision(.fractionLength(2)))
        }
        return scaled.formatted(.number.precision(.fractionLength(0...2))) + Self.suffixes[tier]
    }
}
