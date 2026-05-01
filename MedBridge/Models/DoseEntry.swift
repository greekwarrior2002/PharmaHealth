import Foundation
import SwiftData

@Model
final class DoseEntry {
    var id: UUID
    var medication: Medication?
    var scheduledDate: Date
    var takenDate: Date?
    var skipped: Bool
    var notes: String

    init(
        id: UUID = UUID(),
        medication: Medication? = nil,
        scheduledDate: Date,
        takenDate: Date? = nil,
        skipped: Bool = false,
        notes: String = ""
    ) {
        self.id = id
        self.medication = medication
        self.scheduledDate = scheduledDate
        self.takenDate = takenDate
        self.skipped = skipped
        self.notes = notes
    }

    var status: Status {
        if skipped { return .skipped }
        if takenDate != nil { return .taken }
        if scheduledDate < .now { return .missed }
        return .upcoming
    }

    enum Status {
        case taken
        case missed
        case skipped
        case upcoming
    }
}
