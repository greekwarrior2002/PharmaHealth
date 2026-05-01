import Foundation
import SwiftData

enum DoseFrequency: String, Codable, CaseIterable, Identifiable {
    case oncedaily = "Once Daily"
    case twiceDaily = "Twice Daily"
    case threeTimesDaily = "Three Times Daily"
    case weekly = "Weekly"
    case asNeeded = "As Needed"

    var id: String { rawValue }

    var dosesPerDay: Double {
        switch self {
        case .oncedaily: return 1
        case .twiceDaily: return 2
        case .threeTimesDaily: return 3
        case .weekly: return 1.0 / 7.0
        case .asNeeded: return 0
        }
    }
}

@Model
final class Medication {
    var id: UUID
    var name: String
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

    @Relationship(deleteRule: .cascade, inverse: \DoseEntry.medication)
    var doseLog: [DoseEntry] = []

    @Relationship(inverse: \SymptomLog.relatedMedication)
    var relatedSymptoms: [SymptomLog] = []

    var frequency: DoseFrequency {
        get { DoseFrequency(rawValue: frequencyRaw) ?? .oncedaily }
        set { frequencyRaw = newValue.rawValue }
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
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.dosage = dosage
        self.frequencyRaw = frequency.rawValue
        self.quantityOnHand = quantityOnHand
        self.refillQuantity = refillQuantity
        self.pharmacyName = pharmacyName
        self.pharmacyPhone = pharmacyPhone
        self.lastFillDate = lastFillDate
        self.prescribedBy = prescribedBy
        self.notes = notes
        self.isActive = isActive
    }
}
