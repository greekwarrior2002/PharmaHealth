import Foundation
import SwiftData

@Observable
final class MedicationViewModel {

    func markRefilled(_ medication: Medication, quantity: Int, in context: ModelContext) {
        medication.quantityOnHand = quantity
        medication.lastFillDate = .now
        try? context.save()
        Task { @MainActor in
            NotificationManager.shared.scheduleRefillReminder(for: medication)
        }
    }

    func markDoseTaken(_ medication: Medication, at date: Date = .now, in context: ModelContext) {
        let entry = DoseEntry(
            medication: medication,
            scheduledDate: date,
            takenDate: date,
            skipped: false
        )
        context.insert(entry)
        if medication.quantityOnHand > 0 {
            medication.quantityOnHand -= 1
        }
        try? context.save()
        Task { @MainActor in
            NotificationManager.shared.scheduleRefillReminder(for: medication)
        }
    }

    func markDoseSkipped(_ medication: Medication, at date: Date = .now, in context: ModelContext) {
        let entry = DoseEntry(
            medication: medication,
            scheduledDate: date,
            takenDate: nil,
            skipped: true
        )
        context.insert(entry)
        try? context.save()
    }

    func deleteMedication(_ medication: Medication, in context: ModelContext) {
        Task { @MainActor in
            NotificationManager.shared.cancelNotifications(for: medication)
        }
        context.delete(medication)
        try? context.save()
    }

    func doseLog(for medication: Medication, days: Int = 14) -> [DoseEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        return medication.doseLog
            .filter { $0.scheduledDate >= cutoff }
            .sorted(by: { $0.scheduledDate > $1.scheduledDate })
    }
}
