import SwiftUI

enum WeightFormat {
    static func number(_ kg: Double) -> String {
        kg.formatted(.number.precision(.fractionLength(1)))
    }

    static func kg(_ kg: Double) -> String {
        "\(number(kg)) kg"
    }

    static func delta(_ delta: Double) -> String {
        let sign = delta >= 0.05 ? "+" : delta <= -0.05 ? "−" : ""
        return "\(sign)\(number(abs(delta))) kg"
    }

    /// Green when the change moves towards the target (or down, with no target),
    /// orange when it moves away, grey when flat.
    static func deltaColor(_ delta: Double?, current: Double?, target: Double?) -> Color {
        guard let delta, abs(delta) >= 0.05 else { return .secondary }
        let goingDownIsGood: Bool
        if let target, let current {
            goingDownIsGood = current >= target
        } else {
            goingDownIsGood = true
        }
        return (delta < 0) == goingDownIsGood ? .green : .orange
    }
}
