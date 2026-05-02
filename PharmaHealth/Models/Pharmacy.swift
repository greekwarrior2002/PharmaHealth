import Foundation
import SwiftData

/// A saved pharmacy a user has chosen to associate with one or more medications.
/// Coordinates are stored as raw doubles so the type stays free of CoreLocation
/// imports (kept inside the service layer).
@Model
final class Pharmacy {
    var id: UUID
    var name: String
    var address: String
    var phone: String
    var latitude: Double?
    var longitude: Double?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        address: String = "",
        phone: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.phone = phone
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = createdAt
    }
}
