import Foundation

/// Plausibility ranges used to flag (not reject) suspicious OCR results. The
/// numbers come from the spec — they are intentionally broad so we don't
/// stamp false positives on legitimate edge cases.
enum HealthReadingValidator {

    enum ValidationResult: Equatable {
        case ok
        /// Value is unusual but the user can still save with confirmation.
        case suspicious(String)
        /// Value is impossible for the chosen metric — block save.
        case impossible(String)
    }

    static func validate(
        metric: HealthMetricType,
        primary: Double,
        secondary: Double? = nil,
        unit: String
    ) -> ValidationResult {
        switch metric {
        case .heartRate:
            if primary < 1 || primary > 500 { return .impossible("Heart rate is outside the possible range.") }
            if primary < 20 || primary > 250 { return .suspicious("Heart rate seems unusual.") }
            return .ok

        case .bloodOxygen:
            if primary < 0 || primary > 100 { return .impossible("Oxygen saturation must be between 0% and 100%.") }
            if primary < 50 { return .suspicious("Oxygen saturation seems unusually low.") }
            return .ok

        case .bloodPressure:
            let dia = secondary ?? 0
            if primary < 1 || primary > 400 || dia < 1 || dia > 300 {
                return .impossible("Blood pressure values are outside the possible range.")
            }
            if primary <= dia {
                return .suspicious("Systolic should be higher than diastolic.")
            }
            if primary < 50 || primary > 260 || dia < 30 || dia > 180 {
                return .suspicious("Blood pressure seems unusual.")
            }
            return .ok

        case .temperature:
            if unit.lowercased().contains("f") {
                if primary < 60 || primary > 130 { return .impossible("Temperature is outside the possible range.") }
                if primary < 86 || primary > 113 { return .suspicious("Temperature seems unusual.") }
            } else {
                if primary < 15 || primary > 50 { return .impossible("Temperature is outside the possible range.") }
                if primary < 30 || primary > 45 { return .suspicious("Temperature seems unusual.") }
            }
            return .ok

        case .bloodGlucose:
            // Accept both mg/dL and mmol/L. Plausibility ranges differ.
            if unit.lowercased().contains("mmol") {
                if primary < 0 || primary > 60 { return .impossible("Glucose value is outside the possible range.") }
                if primary < 1 || primary > 35 { return .suspicious("Glucose seems unusual.") }
            } else {
                if primary < 0 || primary > 1500 { return .impossible("Glucose value is outside the possible range.") }
                if primary < 20 || primary > 600 { return .suspicious("Glucose seems unusual.") }
            }
            return .ok

        case .weight:
            // Broad sanity bounds (kg). UI converts pounds before validating.
            if primary < 0 || primary > 1000 { return .impossible("Weight is outside the possible range.") }
            if primary < 1 || primary > 400 { return .suspicious("Weight seems unusual.") }
            return .ok
        }
    }
}
