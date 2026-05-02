import Foundation
import SwiftData

/// The kinds of health readings the app currently understands. Adding a case
/// here keeps the parser, validator, and UI in lockstep — every place that
/// switches on this enum becomes a compile-time TODO.
enum HealthMetricType: String, Codable, CaseIterable, Identifiable {
    case bloodPressure  = "Blood Pressure"
    case bloodOxygen    = "Blood Oxygen"
    case heartRate      = "Heart Rate"
    case weight         = "Weight"
    case temperature    = "Temperature"
    case bloodGlucose   = "Blood Glucose"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .bloodPressure: return "heart.text.square.fill"
        case .bloodOxygen:   return "lungs.fill"
        case .heartRate:     return "heart.fill"
        case .weight:        return "scalemass.fill"
        case .temperature:   return "thermometer"
        case .bloodGlucose:  return "drop.fill"
        }
    }

    /// Default unit for this metric (used when the parser can't determine one).
    var defaultUnit: String {
        switch self {
        case .bloodPressure: return "mmHg"
        case .bloodOxygen:   return "%"
        case .heartRate:     return "bpm"
        case .weight:        return "kg"
        case .temperature:   return "°C"
        case .bloodGlucose:  return "mg/dL"
        }
    }
}

/// Where a reading came from. `cameraScan` means it was extracted via OCR.
enum HealthReadingSource: String, Codable {
    case manual         = "Manual"
    case cameraScan     = "Camera scan"
    case healthKit      = "Apple Health"
}

@Model
final class HealthReading {
    var id: UUID
    /// Stored raw to allow extending the enum without breaking older records.
    var metricRaw: String
    /// Primary numeric value (e.g. 120 mmHg systolic, 98 % SpO₂, 72 bpm).
    var primaryValue: Double
    /// Optional secondary value — only used today by blood pressure (diastolic).
    var secondaryValue: Double?
    var unit: String
    var date: Date
    var sourceRaw: String
    var note: String

    /// True when the value passed plausibility validation at save time. Older
    /// records default to `true` so we never accidentally hide history.
    var isValidated: Bool = true

    init(
        id: UUID = UUID(),
        metric: HealthMetricType,
        primaryValue: Double,
        secondaryValue: Double? = nil,
        unit: String,
        date: Date = .now,
        source: HealthReadingSource = .manual,
        note: String = "",
        isValidated: Bool = true
    ) {
        self.id = id
        self.metricRaw = metric.rawValue
        self.primaryValue = primaryValue
        self.secondaryValue = secondaryValue
        self.unit = unit
        self.date = date
        self.sourceRaw = source.rawValue
        self.note = note
        self.isValidated = isValidated
    }

    var metric: HealthMetricType {
        get { HealthMetricType(rawValue: metricRaw) ?? .heartRate }
        set { metricRaw = newValue.rawValue }
    }

    var source: HealthReadingSource {
        get { HealthReadingSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    /// User-facing summary, e.g. "120 / 80 mmHg" or "72 bpm".
    var displayValue: String {
        switch metric {
        case .bloodPressure:
            let dia = secondaryValue.map { Int($0) } ?? 0
            return "\(Int(primaryValue)) / \(dia) \(unit)"
        case .bloodOxygen:
            return "\(Int(primaryValue))\(unit)"
        case .heartRate:
            return "\(Int(primaryValue)) \(unit)"
        case .weight, .temperature, .bloodGlucose:
            // Show one decimal for these — they're often non-integers.
            let formatted = String(format: "%.1f", primaryValue)
            return "\(formatted) \(unit)"
        }
    }
}
