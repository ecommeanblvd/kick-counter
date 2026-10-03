import Foundation

enum Formatting {
    /// Shown when a value is not available (e.g. baby measurements before week 8).
    static let missingValue = "—"

    /// e.g. "23 min", "1 hr, 5 min", "45 sec" — localized by the system.
    static func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds.rounded())
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2))
    }

    /// e.g. "30 cm", "1,6 cm" — localized by the system.
    static func length(cm: Double?) -> String {
        guard let cm else { return missingValue }
        return Measurement(value: cm, unit: UnitLength.centimeters).formatted(
            .measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0...1)))
        )
    }

    /// Grams below 1 kg ("600 g"), kilograms above ("3,08 kg").
    static func weight(grams: Double?) -> String {
        guard let grams else { return missingValue }
        if grams >= 1000 {
            return Measurement(value: grams / 1000, unit: UnitMass.kilograms).formatted(
                .measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0...2)))
            )
        }
        return Measurement(value: grams, unit: UnitMass.grams).formatted(
            .measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0)))
        )
    }
}
