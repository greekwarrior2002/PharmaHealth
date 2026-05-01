import Foundation
import SwiftData

@Model
final class SymptomLog {
    var id: UUID
    var date: Date
    var overallFeeling: Int
    var symptoms: [String]
    var notes: String
    var relatedMedication: Medication?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        overallFeeling: Int = 3,
        symptoms: [String] = [],
        notes: String = "",
        relatedMedication: Medication? = nil
    ) {
        self.id = id
        self.date = date
        self.overallFeeling = overallFeeling
        self.symptoms = symptoms
        self.notes = notes
        self.relatedMedication = relatedMedication
    }

    var feelingEmoji: String {
        switch overallFeeling {
        case 1: return "😣"
        case 2: return "🙁"
        case 3: return "😐"
        case 4: return "🙂"
        case 5: return "😄"
        default: return "😐"
        }
    }

    var feelingLabel: String {
        switch overallFeeling {
        case 1: return "Very bad"
        case 2: return "Bad"
        case 3: return "Okay"
        case 4: return "Good"
        case 5: return "Very good"
        default: return "Okay"
        }
    }
}
