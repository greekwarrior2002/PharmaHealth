import Foundation
import UserNotifications
import UIKit

@MainActor
final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    enum Category: String {
        case refill = "REFILL"
        case dose = "DOSE"
        case appointment = "APPOINTMENT"
    }

    enum Action: String {
        case callPharmacy = "CALL_PHARMACY"
        case snoozeRefill = "SNOOZE_REFILL"
        case markTaken = "MARK_TAKEN"
        case skipDose = "SKIP_DOSE"
    }

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        registerCategories()
    }

    func registerCategories() {
        let callAction = UNNotificationAction(
            identifier: Action.callPharmacy.rawValue,
            title: "Call Pharmacy",
            options: [.foreground]
        )
        let snoozeAction = UNNotificationAction(
            identifier: Action.snoozeRefill.rawValue,
            title: "Remind me tomorrow",
            options: []
        )
        let refillCategory = UNNotificationCategory(
            identifier: Category.refill.rawValue,
            actions: [callAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        let takenAction = UNNotificationAction(
            identifier: Action.markTaken.rawValue,
            title: "Mark as Taken",
            options: []
        )
        let skipAction = UNNotificationAction(
            identifier: Action.skipDose.rawValue,
            title: "Skip",
            options: [.destructive]
        )
        let doseCategory = UNNotificationCategory(
            identifier: Category.dose.rawValue,
            actions: [takenAction, skipAction],
            intentIdentifiers: [],
            options: []
        )

        let appointmentCategory = UNNotificationCategory(
            identifier: Category.appointment.rawValue,
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            refillCategory, doseCategory, appointmentCategory
        ])
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            return false
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        self.authorizationStatus = settings.authorizationStatus
    }

    // MARK: - Refill

    func scheduleRefillReminder(for medication: Medication) {
        cancelRefillReminder(for: medication)
        guard let date = RefillCalculator.refillCallReminderDate(medication: medication),
              date > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time to call \(medication.pharmacyName)"
        content.body = "You have about 5 days of \(medication.name) left. Tap to call."
        content.sound = .default
        content.categoryIdentifier = Category.refill.rawValue
        content.userInfo = [
            "medicationID": medication.id.uuidString,
            "pharmacyPhone": medication.pharmacyPhone,
            "pharmacyName": medication.pharmacyName,
            "medicationName": medication.name
        ]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: refillIdentifier(for: medication),
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelRefillReminder(for medication: Medication) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [refillIdentifier(for: medication)]
        )
    }

    private func refillIdentifier(for medication: Medication) -> String {
        "refill-\(medication.id.uuidString)"
    }

    // MARK: - Dose

    func scheduleDoseReminder(for medication: Medication, at time: Date) {
        cancelDoseReminder(for: medication)
        let content = UNMutableNotificationContent()
        content.title = "Time for \(medication.name)"
        content.body = "\(medication.dosage) — \(medication.frequency.rawValue)"
        content.sound = .default
        content.categoryIdentifier = Category.dose.rawValue
        content.userInfo = ["medicationID": medication.id.uuidString]

        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: doseIdentifier(for: medication),
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelDoseReminder(for medication: Medication) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [doseIdentifier(for: medication)]
        )
    }

    private func doseIdentifier(for medication: Medication) -> String {
        "dose-\(medication.id.uuidString)"
    }

    // MARK: - Appointment

    func scheduleAppointmentReminder(for appointment: Appointment) {
        cancelAppointmentReminder(for: appointment)
        guard let triggerDate = Calendar.current.date(byAdding: .day, value: -1, to: appointment.date),
              triggerDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Visit with Dr. \(appointment.doctorName) tomorrow"
        content.body = "Tap to review your prep summary"
        content.sound = .default
        content.categoryIdentifier = Category.appointment.rawValue
        content.userInfo = ["appointmentID": appointment.id.uuidString]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: appointmentIdentifier(for: appointment),
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelAppointmentReminder(for appointment: Appointment) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [appointmentIdentifier(for: appointment)]
        )
    }

    private func appointmentIdentifier(for appointment: Appointment) -> String {
        "appointment-\(appointment.id.uuidString)"
    }

    // MARK: - Bulk

    func cancelNotifications(for medication: Medication) {
        cancelRefillReminder(for: medication)
        cancelDoseReminder(for: medication)
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let actionID = response.actionIdentifier

        await MainActor.run {
            NotificationActionRouter.shared.handle(actionID: actionID, userInfo: userInfo)
        }
    }
}

@MainActor
final class NotificationActionRouter: ObservableObject {
    static let shared = NotificationActionRouter()

    @Published var pendingMedicationID: UUID?
    @Published var pendingAppointmentID: UUID?

    func handle(actionID: String, userInfo: [AnyHashable: Any]) {
        switch actionID {
        case NotificationManager.Action.callPharmacy.rawValue:
            if let phone = userInfo["pharmacyPhone"] as? String,
               !phone.isEmpty,
               let url = URL(string: "tel://\(phone.filter { $0.isNumber })") {
                UIApplication.shared.open(url)
            }
        case NotificationManager.Action.snoozeRefill.rawValue:
            // Reschedule +24h with same content
            if let phone = userInfo["pharmacyPhone"] as? String,
               let pharmacy = userInfo["pharmacyName"] as? String,
               let medName = userInfo["medicationName"] as? String,
               let medIDString = userInfo["medicationID"] as? String {
                snoozeRefill(medicationID: medIDString, pharmacy: pharmacy, phone: phone, medName: medName)
            }
        case NotificationManager.Action.markTaken.rawValue,
             NotificationManager.Action.skipDose.rawValue:
            if let medIDString = userInfo["medicationID"] as? String,
               let medID = UUID(uuidString: medIDString) {
                pendingMedicationID = medID
                NotificationCenter.default.post(
                    name: .doseActionReceived,
                    object: nil,
                    userInfo: [
                        "medicationID": medID,
                        "skipped": actionID == NotificationManager.Action.skipDose.rawValue
                    ]
                )
            }
        default:
            if let appointmentIDString = userInfo["appointmentID"] as? String,
               let id = UUID(uuidString: appointmentIDString) {
                pendingAppointmentID = id
            }
            if let medIDString = userInfo["medicationID"] as? String,
               let id = UUID(uuidString: medIDString) {
                pendingMedicationID = id
            }
        }
    }

    private func snoozeRefill(medicationID: String, pharmacy: String, phone: String, medName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Time to call \(pharmacy)"
        content.body = "Reminder: \(medName) refill — tap to call."
        content.sound = .default
        content.categoryIdentifier = NotificationManager.Category.refill.rawValue
        content.userInfo = [
            "medicationID": medicationID,
            "pharmacyPhone": phone,
            "pharmacyName": pharmacy,
            "medicationName": medName
        ]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 24 * 60 * 60, repeats: false)
        let request = UNNotificationRequest(
            identifier: "refill-snooze-\(medicationID)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
}

extension Notification.Name {
    static let doseActionReceived = Notification.Name("doseActionReceived")
}
