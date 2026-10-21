import SwiftUI

enum WeightFormat {
    static func number(_ kg: Double) -> String {
        kg.formatted(.number.precision(.fractionLength(1)))
    }

    static func kg(_ kg: Double) -> String {
        "\(number(kg)) kg"
    }

    /// Changes smaller than this (in kg) show as 0.0 at one decimal place, so they count as
    /// unchanged: no sign and grey.
    static let flatThreshold = 0.05

    static func isFlat(_ delta: Double) -> Bool {
        abs(delta) < flatThreshold
    }

    static func delta(_ delta: Double) -> String {
        let sign = isFlat(delta) ? "" : delta > 0 ? "+" : "−"
        return "\(sign)\(number(abs(delta))) kg"
    }

    /// Green when the average went down, amber when it went up, grey when flat.
    static func deltaColor(_ delta: Double) -> Color {
        isFlat(delta) ? .secondary : delta < 0 ? .green : .orange
    }
}
