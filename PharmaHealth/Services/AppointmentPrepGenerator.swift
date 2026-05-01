import Foundation

struct AppointmentPrepGenerator {

    @MainActor
    static func generatePrepSummary(
        appointment: Appointment,
        medications: [Medication],
        recentSymptoms: [SymptomLog],
        recentDoseLog: [DoseEntry]
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        var output = ""
        output += "APPOINTMENT PREP\n"
        output += "Dr. \(appointment.doctorName)"
        if !appointment.specialty.isEmpty {
            output += " — \(appointment.specialty)"
        }
        output += "\n\(formatter.string(from: appointment.date))\n"
        if !appointment.location.isEmpty {
            output += "\(appointment.location)\n"
        }
        output += "\n"

        // Current Medications
        output += "CURRENT MEDICATIONS\n"
        output += String(repeating: "-", count: 30) + "\n"
        let activeMeds = medications.filter { $0.isActive }
        if activeMeds.isEmpty {
            output += "No medications recorded.\n"
        } else {
            for med in activeMeds {
                output += "• \(med.name) \(med.dosage) — \(med.frequency.rawValue)\n"
            }
        }
        output += "\n"

        // Recent Changes (medications added or refilled in last 30 days)
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        let recentlyChanged = activeMeds.filter { $0.lastFillDate >= thirtyDaysAgo }
        output += "RECENT CHANGES (Last 30 Days)\n"
        output += String(repeating: "-", count: 30) + "\n"
        if recentlyChanged.isEmpty {
            output += "No medication changes recorded.\n"
        } else {
            for med in recentlyChanged {
                output += "• \(med.name) — last filled \(formatter.string(from: med.lastFillDate))\n"
            }
        }
        output += "\n"

        // Missed Doses
        output += "MISSED DOSES (Last 30 Days)\n"
        output += String(repeating: "-", count: 30) + "\n"
        let missedDoses = recentDoseLog.filter {
            $0.scheduledDate >= thirtyDaysAgo &&
            $0.takenDate == nil &&
            !$0.skipped &&
            $0.scheduledDate < .now
        }
        if missedDoses.isEmpty {
            output += "No missed doses recorded.\n"
        } else {
            let grouped = Dictionary(grouping: missedDoses) { $0.medication?.name ?? "Unknown" }
            for (medName, entries) in grouped.sorted(by: { $0.key < $1.key }) {
                output += "• \(medName): \(entries.count) missed dose\(entries.count == 1 ? "" : "s")\n"
            }
        }
        output += "\n"

        // Recent Symptoms
        output += "RECENT SYMPTOMS (Last 30 Days)\n"
        output += String(repeating: "-", count: 30) + "\n"
        let recent = recentSymptoms.filter { $0.date >= thirtyDaysAgo }
        if recent.isEmpty {
            output += "No symptoms logged.\n"
        } else {
            var symptomDates: [String: [Date]] = [:]
            for log in recent {
                for s in log.symptoms {
                    symptomDates[s, default: []].append(log.date)
                }
            }
            for (symptom, dates) in symptomDates.sorted(by: { $0.key < $1.key }) {
                let dateStr = dates.sorted().map { formatter.string(from: $0) }.joined(separator: ", ")
                output += "• \(symptom) (\(dates.count)x): \(dateStr)\n"
            }

            let avgFeeling = Double(recent.map { $0.overallFeeling }.reduce(0, +)) / Double(recent.count)
            output += "\nAverage feeling: \(String(format: "%.1f", avgFeeling))/5\n"
        }
        output += "\n"

        // Questions to Ask
        output += "QUESTIONS TO ASK\n"
        output += String(repeating: "-", count: 30) + "\n"
        output += "• \n"
        output += "• \n"
        output += "• \n"

        let result = output
        appointment.prepSummary = result
        return result
    }
}
