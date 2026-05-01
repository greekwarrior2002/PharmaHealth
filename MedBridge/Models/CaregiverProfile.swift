import Foundation
import SwiftData

@Model
final class CaregiverProfile {
    var id: UUID
    var patientName: String
    var caregiverName: String?
    var shareCode: String?

    init(
        id: UUID = UUID(),
        patientName: String,
        caregiverName: String? = nil,
        shareCode: String? = nil
    ) {
        self.id = id
        self.patientName = patientName
        self.caregiverName = caregiverName
        self.shareCode = shareCode
    }
}
