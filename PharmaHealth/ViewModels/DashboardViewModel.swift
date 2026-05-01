import Foundation
import SwiftData

@Observable
final class DashboardViewModel {
    var todayDoses: [DoseEntry] = []

    func todaysScheduledDoses(medications: [Medication], allDoses: [DoseEntry]) -> [DoseEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }

        return allDoses.filter { entry in
            entry.scheduledDate >= today && entry.scheduledDate < tomorrow
        }.sorted(by: { $0.scheduledDate < $1.scheduledDate })
    }

    func urgentMedications(medications: [Medication]) -> [Medication] {
        medications.filter {
            $0.isActive && RefillCalculator.shouldShowRefillAlert(medication: $0)
        }
    }

    func upcomingAppointments(appointments: [Appointment], limit: Int = 2) -> [Appointment] {
        appointments
            .filter { $0.isUpcoming }
            .sorted(by: { $0.date < $1.date })
            .prefix(limit)
            .map { $0 }
    }
}
