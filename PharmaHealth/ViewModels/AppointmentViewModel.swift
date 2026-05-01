import Foundation
import SwiftData

@Observable
final class AppointmentViewModel {

    @MainActor
    func generatePrep(
        for appointment: Appointment,
        medications: [Medication],
        symptoms: [SymptomLog],
        doseLog: [DoseEntry],
        context: ModelContext
    ) -> String {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        let recentSymptoms = symptoms.filter { $0.date >= cutoff }
        let recentDoses = doseLog.filter { $0.scheduledDate >= cutoff }

        let summary = AppointmentPrepGenerator.generatePrepSummary(
            appointment: appointment,
            medications: medications,
            recentSymptoms: recentSymptoms,
            recentDoseLog: recentDoses
        )
        try? context.save()
        return summary
    }

    func deleteAppointment(_ appointment: Appointment, in context: ModelContext) {
        Task { @MainActor in
            NotificationManager.shared.cancelAppointmentReminder(for: appointment)
        }
        context.delete(appointment)
        try? context.save()
    }
}
