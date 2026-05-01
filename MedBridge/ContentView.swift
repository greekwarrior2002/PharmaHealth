import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(filter: #Predicate<Medication> { $0.isActive == true })
    private var activeMedications: [Medication]

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    @State private var selectedTab: Int = 0

    private var urgentCount: Int {
        activeMedications.filter { RefillCalculator.shouldShowRefillAlert(medication: $0) }.count
    }

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView()
            } else {
                TabView(selection: $selectedTab) {
                    DashboardView()
                        .tabItem {
                            Label("Home", systemImage: "house.fill")
                        }
                        .tag(0)

                    MedicationListView()
                        .tabItem {
                            Label("Medications", systemImage: "pills.fill")
                        }
                        .badge(urgentCount > 0 ? urgentCount : 0)
                        .tag(1)

                    SymptomLogView()
                        .tabItem {
                            Label("Log", systemImage: "heart.text.square")
                        }
                        .tag(2)

                    AppointmentListView()
                        .tabItem {
                            Label("Appointments", systemImage: "calendar")
                        }
                        .tag(3)

                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gearshape.fill")
                        }
                        .tag(4)
                }
                .tint(.mbPrimary)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            Medication.self, DoseEntry.self, SymptomLog.self,
            Appointment.self, CaregiverProfile.self
        ], inMemory: true)
}
