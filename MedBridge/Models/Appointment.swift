import Foundation
import SwiftData

@Model
final class Appointment {
    var id: UUID
    var doctorName: String
    var specialty: String
    var date: Date
    var location: String
    var prepSummary: String?
    var postVisitNotes: String?
    var newInstructions: String?
    var isCompleted: Bool

    init(
        id: UUID = UUID(),
        doctorName: String,
        specialty: String = "",
        date: Date,
        location: String = "",
        prepSummary: String? = nil,
        postVisitNotes: String? = nil,
        newInstructions: String? = nil,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.doctorName = doctorName
        self.specialty = specialty
        self.date = date
        self.location = location
        self.prepSummary = prepSummary
        self.postVisitNotes = postVisitNotes
        self.newInstructions = newInstructions
        self.isCompleted = isCompleted
    }

    var isUpcoming: Bool {
        !isCompleted && date >= .now
    }

    var isPast: Bool {
        date < .now
    }
}
