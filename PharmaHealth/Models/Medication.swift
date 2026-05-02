import Foundation
import SwiftData

enum DoseFrequency: String, Codable, CaseIterable, Identifiable {
    case oncedaily = "Once Daily"
    case twiceDaily = "Twice Daily"
    case threeTimesDaily = "Three Times Daily"
    case fourTimesDaily = "Four Times Daily"
    case weekly = "Weekly"
    case asNeeded = "As Needed"

    var id: String { rawValue }

    var dosesPerDay: Double {
        switch self {
        case .oncedaily: return 1
        case .twiceDaily: return 2
        case .threeTimesDaily: return 3
        case .fourTimesDaily: return 4
        case .weekly: return 1.0 / 7.0
        case .asNeeded: return 0
        }
    }
}

/// Physical form of the medication. Used to label inventory units and to pick
/// sensible default dose units in the UI. Stored as a raw string so SwiftData
/// can additively migrate older records (which default to `.tablet`).
enum MedicationForm: String, Codable, CaseIterable, Identifiable {
    case tablet     = "Tablet"
    case capsule    = "Capsule"
    case liquid     = "Liquid"
    case injection  = "Injection"
    case inhaler    = "Inhaler"
    case cream      = "Cream"
    case drops      = "Drops"
    case patch      = "Patch"
    case other      = "Other"

    var id: String { rawValue }

    /// Plural unit label used in the UI (e.g. "30 tablets").
    var unitLabel: String {
        switch self {
        case .tablet:    return "tablets"
        case .capsule:   return "capsules"
        case .liquid:    return "mL"
        case .injection: return "doses"
        case .inhaler:   return "puffs"
        case .cream:     return "applications"
        case .drops:     return "drops"
        case .patch:     return "patches"
        case .other:     return "units"
        }
    }

    /// Default dose unit suggested when the user picks this form.
    var defaultDoseUnit: String {
        switch self {
        case .tablet, .capsule:   return "mg"
        case .liquid:             return "mL"
        case .injection:          return "mL"
        case .inhaler:            return "puff"
        case .cream:              return "g"
        case .drops:              return "drop"
        case .patch:              return "patch"
        case .other:              return ""
        }
    }
}

@Model
final class Medication {
    var id: UUID
    var name: String
    /// Free-text dosage label kept for back-compat (e.g. "10mg"). New
    /// medications also fill in `doseAmount` + `doseUnit` for structured use.
    var dosage: String
    var frequencyRaw: String
    var quantityOnHand: Int
    var refillQuantity: Int
    var pharmacyName: String
    var pharmacyPhone: String
    var lastFillDate: Date
    var prescribedBy: String
    var notes: String
    var isActive: Bool

    // MARK: - New (additive, SwiftData-safe) fields

    /// Stored raw to allow SwiftData lightweight migration with default value.
    /// Defaults to "Tablet" so existing rows decode cleanly.
    var formRaw: String = MedicationForm.tablet.rawValue

    /// Structured dose amount — optional so old records remain valid.
    var doseAmount: Double?

    /// Structured dose unit (e.g. "mg", "mL", "puff").
    var doseUnit: String?

    /// Optional link to a saved Pharmacy. Kept loose (not a relationship)
    /// because the same pharmacy may be shared across many medications and
    /// changing the model relationship would require a heavier migration.
    var pharmacyID: UUID?

    @Relationship(deleteRule: .cascade, inverse: \DoseEntry.medication)
    var doseLog: [DoseEntry] = []

    @Relationship(inverse: \SymptomLog.relatedMedication)
    var relatedSymptoms: [SymptomLog] = []

    var frequency: DoseFrequency {
        get { DoseFrequency(rawValue: frequencyRaw) ?? .oncedaily }
        set { frequencyRaw = newValue.rawValue }
    }

    var form: MedicationForm {
        get { MedicationForm(rawValue: formRaw) ?? .tablet }
        set { formRaw = newValue.rawValue }
    }

    /// Human-friendly dose label, preferring structured fields when available.
    var displayDose: String {
        if let amount = doseAmount, let unit = doseUnit, !unit.isEmpty {
            // Trim ".0" off whole numbers for cleaner display.
            let formatted = amount.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(amount))
                : String(amount)
            return "\(formatted) \(unit)"
        }
        return dosage
    }

    init(
        id: UUID = UUID(),
        name: String,
        dosage: String,
        frequency: DoseFrequency,
        quantityOnHand: Int,
        refillQuantity: Int = 90,
        pharmacyName: String,
        pharmacyPhone: String = "",
        lastFillDate: Date = .now,
        prescribedBy: String = "",
        notes: String = "",
        isActive: Bool = true,
        form: MedicationForm = .tablet,
        doseAmount: Double? = nil,
        doseUnit: String? = nil,
        pharmacyID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.dosage = dosage
        self.frequencyRaw = frequency.rawValue
        self.quantityOnHand = max(0, quantityOnHand)
        self.refillQuantity = max(1, refillQuantity)
        self.pharmacyName = pharmacyName
        self.pharmacyPhone = pharmacyPhone
        self.lastFillDate = lastFillDate
        self.prescribedBy = prescribedBy
        self.notes = notes
        self.isActive = isActive
        self.formRaw = form.rawValue
        self.doseAmount = doseAmount
        self.doseUnit = doseUnit
        self.pharmacyID = pharmacyID
    }
}
