import Foundation

struct RefillCalculator {

    static var defaultLeadTime: Int {
        let stored = UserDefaults.standard.integer(forKey: "refillLeadTimeDays")
        return stored == 0 ? 5 : stored
    }

    static func daysUntilRunOut(medication: Medication, asOf reference: Date = .now) -> Int? {
        let dosesPerDay = medication.frequency.dosesPerDay
        guard dosesPerDay > 0 else { return nil }
        let days = Double(medication.quantityOnHand) / dosesPerDay
        return max(0, Int(days.rounded(.down)))
    }

    static func estimatedRunOutDate(medication: Medication, asOf reference: Date = .now) -> Date? {
        guard let days = daysUntilRunOut(medication: medication, asOf: reference) else { return nil }
        return Calendar.current.date(byAdding: .day, value: days, to: reference)
    }

    static func shouldShowRefillAlert(medication: Medication, asOf reference: Date = .now) -> Bool {
        guard let days = daysUntilRunOut(medication: medication, asOf: reference) else { return false }
        return days <= 7
    }

    static func refillCallReminderDate(
        medication: Medication,
        leadTimeDays: Int = defaultLeadTime,
        asOf reference: Date = .now
    ) -> Date? {
        guard let runOut = estimatedRunOutDate(medication: medication, asOf: reference) else { return nil }
        return Calendar.current.date(byAdding: .day, value: -leadTimeDays, to: runOut)
    }

    enum UrgencyLevel {
        case good, warning, urgent, unknown
    }

    static func urgency(for medication: Medication, asOf reference: Date = .now) -> UrgencyLevel {
        guard let days = daysUntilRunOut(medication: medication, asOf: reference) else { return .unknown }
        if days <= 7 { return .urgent }
        if days <= 13 { return .warning }
        return .good
    }
}
