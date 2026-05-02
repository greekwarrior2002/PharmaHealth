import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Medication> { $0.isActive == true })
    private var medications: [Medication]
    @Query private var doseLog: [DoseEntry]
    @Query private var appointments: [Appointment]
    @Query private var profiles: [CaregiverProfile]

    @State private var viewModel = DashboardViewModel()
    @State private var medViewModel = MedicationViewModel()
    @State private var showingAddSymptom = false

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let timeOfDay: String
        switch hour {
        case 5..<12: timeOfDay = "Good morning"
        case 12..<17: timeOfDay = "Good afternoon"
        default: timeOfDay = "Good evening"
        }
        if let name = profiles.first?.patientName, !name.isEmpty {
            return "\(timeOfDay), \(name)"
        }
        return timeOfDay
    }

    private var urgentMeds: [Medication] {
        viewModel.urgentMedications(medications: medications)
    }

    private var todaysDoses: [DoseEntry] {
        viewModel.todaysScheduledDoses(medications: medications, allDoses: doseLog)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(greeting)
                        .font(.largeTitle.weight(.bold))
                        .padding(.horizontal)

                    if let urgent = urgentMeds.first {
                        refillBanner(for: urgent)
                            .padding(.horizontal)
                    }

                    if !medications.isEmpty {
                        medicationCardsSection
                    } else {
                        emptyState
                            .padding(.horizontal)
                    }

                    todaysDosesSection
                        .padding(.horizontal)

                    upcomingAppointmentsSection
                        .padding(.horizontal)

                    Button {
                        showingAddSymptom = true
                    } label: {
                        Label("Log how you're feeling", systemImage: "heart.text.square")
                    }
                    .mbPrimaryButton()
                    .padding(.horizontal)
                    .accessibilityLabel("Log how you're feeling today")

                    Spacer(minLength: 32)
                }
                .padding(.top)
            }
            .background(Color.mbBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddSymptom) {
                AddSymptomView()
            }
        }
    }

    private func refillBanner(for medication: Medication) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(.white)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Time to refill \(medication.name)")
                    .font(.headline)
                    .foregroundColor(.white)
                if let days = RefillCalculator.daysUntilRunOut(medication: medication) {
                    Text("About \(days) days left")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.95))
                }
            }
            Spacer()
            if let url = medication.pharmacyPhone.phoneURL {
                Link(destination: url) {
                    Text("Call")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(Color.white)
                        .foregroundColor(.mbUrgent)
                        .cornerRadius(10)
                }
                .accessibilityLabel("Call \(medication.pharmacyName)")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.mbUrgent)
        )
    }

    private var medicationCardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your medications")
                .font(.title2.weight(.semibold))
                .padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(medications) { medication in
                        NavigationLink {
                            MedicationDetailView(medication: medication)
                        } label: {
                            MedicationStatusCard(medication: medication)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var todaysDosesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's doses")
                .font(.title2.weight(.semibold))
            if todaysDoses.isEmpty {
                Text("No doses scheduled today.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.mbSurface)
                    )
            } else {
                VStack(spacing: 8) {
                    ForEach(todaysDoses) { dose in
                        DoseEntryRow(dose: dose)
                    }
                }
            }
        }
    }

    private var upcomingAppointmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming appointments")
                .font(.title2.weight(.semibold))
            let upcoming = viewModel.upcomingAppointments(appointments: appointments)
            if upcoming.isEmpty {
                Text("No appointments scheduled.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.mbSurface)
                    )
            } else {
                ForEach(upcoming) { appointment in
                    NavigationLink {
                        AppointmentDetailView(appointment: appointment)
                    } label: {
                        appointmentRow(appointment)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func appointmentRow(_ appointment: Appointment) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.title2)
                .foregroundColor(.mbPrimary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Dr. \(appointment.doctorName)")
                    .font(.headline)
                Text(appointment.date.mbDateTime())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
        }
        .mbCard()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "pills.fill")
                .font(.system(size: 48))
                .foregroundColor(.mbPrimary.opacity(0.6))
                .accessibilityHidden(true)
            Text("Add your first medication")
                .font(.headline)
            Text("Track when you'll need a refill and when to call the pharmacy.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            NavigationLink {
                AddMedicationView()
            } label: {
                Text("Add medication")
            }
            .mbPrimaryButton()
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.mbSurface)
        )
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [
            Medication.self, DoseEntry.self, SymptomLog.self,
            Appointment.self, CaregiverProfile.self,
            Pharmacy.self, HealthReading.self
        ], inMemory: true)
}
