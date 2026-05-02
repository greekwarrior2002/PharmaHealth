import Foundation
import SwiftData
import SwiftUI

/// User-level preferences for pharmacies. Today this owns the single
/// "default pharmacy" the user wants to use across new medications.
///
/// The actual pharmacy rows live in SwiftData (`Pharmacy`); this service only
/// persists a pointer (UUID string) in `UserDefaults` so the preference is
/// independent of any one medication and survives row deletions gracefully.
@MainActor
final class PharmacyPreferencesService: ObservableObject {

    static let defaultPharmacyIDKey = "defaultPharmacyID"

    @Published private(set) var defaultPharmacyID: UUID?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: Self.defaultPharmacyIDKey),
           let id = UUID(uuidString: raw) {
            self.defaultPharmacyID = id
        } else {
            self.defaultPharmacyID = nil
        }
    }

    /// Returns the persisted default pharmacy if it still exists, otherwise
    /// clears the stale preference and returns nil. Self-healing: protects
    /// against the user deleting the underlying pharmacy row.
    func defaultPharmacy(in context: ModelContext) -> Pharmacy? {
        guard let id = defaultPharmacyID else { return nil }
        let descriptor = FetchDescriptor<Pharmacy>(
            predicate: #Predicate { $0.id == id }
        )
        if let match = try? context.fetch(descriptor).first {
            return match
        }
        clearDefault(in: context)
        return nil
    }

    /// Marks `pharmacy` as the user's default. Flips its `isFavorite` flag and
    /// clears the flag on the previously-default pharmacy so the "Default"
    /// badge always corresponds to a single row.
    func setDefault(_ pharmacy: Pharmacy, in context: ModelContext) {
        if let previousID = defaultPharmacyID, previousID != pharmacy.id {
            let descriptor = FetchDescriptor<Pharmacy>(
                predicate: #Predicate { $0.id == previousID }
            )
            if let previous = try? context.fetch(descriptor).first {
                previous.isFavorite = false
            }
        }
        pharmacy.isFavorite = true
        defaultPharmacyID = pharmacy.id
        defaults.set(pharmacy.id.uuidString, forKey: Self.defaultPharmacyIDKey)
        try? context.save()
    }

    /// Removes the default pharmacy preference. Does not delete the underlying
    /// `Pharmacy` row — medications that reference it keep working.
    func clearDefault(in context: ModelContext) {
        if let id = defaultPharmacyID {
            let descriptor = FetchDescriptor<Pharmacy>(
                predicate: #Predicate { $0.id == id }
            )
            if let pharmacy = try? context.fetch(descriptor).first {
                pharmacy.isFavorite = false
            }
        }
        defaultPharmacyID = nil
        defaults.removeObject(forKey: Self.defaultPharmacyIDKey)
        try? context.save()
    }

    /// True when the supplied pharmacy id matches the saved default.
    func isDefault(_ id: UUID?) -> Bool {
        guard let id else { return false }
        return defaultPharmacyID == id
    }
}
