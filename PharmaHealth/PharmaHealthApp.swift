import SwiftUI
import SwiftData

@main
struct PharmaHealthApp: App {

    // TODO: Replace with your bundle identifier (matching App Group entitlements).
    static let appGroupIdentifier = "group.com.yourdomain.pharmahealth"

    let modelContainer: ModelContainer

    init() {
        SubscriptionManager.configure()

        let schema = Schema([
            Medication.self,
            DoseEntry.self,
            SymptomLog.self,
            Appointment.self,
            CaregiverProfile.self,
            Pharmacy.self,
            HealthReading.self
        ])

        // Try to use the App Group container so the widget can read the same store.
        let groupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier)?
            .appendingPathComponent("PharmaHealth.store")

        do {
            let config: ModelConfiguration
            if let groupURL = groupURL {
                config = ModelConfiguration(schema: schema, url: groupURL)
            } else {
                config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            }
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        _ = NotificationManager.shared
    }

    @StateObject private var pharmacyPreferences = PharmacyPreferencesService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(pharmacyPreferences)
                .task {
                    await SubscriptionManager.shared.refresh()
                    await NotificationManager.shared.refreshAuthorizationStatus()
                    handlePendingDoseActions()
                }
        }
        .modelContainer(modelContainer)
    }

    private func handlePendingDoseActions() {
        NotificationCenter.default.addObserver(
            forName: .doseActionReceived,
            object: nil,
            queue: .main
        ) { notification in
            guard let medID = notification.userInfo?["medicationID"] as? UUID,
                  let skipped = notification.userInfo?["skipped"] as? Bool else { return }

            let context = ModelContext(modelContainer)
            let descriptor = FetchDescriptor<Medication>(
                predicate: #Predicate { $0.id == medID }
            )
            guard let medication = try? context.fetch(descriptor).first else { return }

            let entry = DoseEntry(
                medication: medication,
                scheduledDate: .now,
                takenDate: skipped ? nil : .now,
                skipped: skipped
            )
            context.insert(entry)
            if !skipped, medication.quantityOnHand > 0 {
                medication.quantityOnHand -= 1
            }
            try? context.save()
        }
    }
}
