import SwiftUI
import SwiftData

struct AppointmentListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Appointment.date) private var appointments: [Appointment]
    @State private var apptViewModel = AppointmentViewModel()
    @State private var showingAdd = false

    private var upcoming: [Appointment] {
        appointments.filter { $0.isUpcoming }
    }

    private var past: [Appointment] {
        appointments.filter { !$0.isUpcoming }.sorted(by: { $0.date > $1.date })
    }

    var body: some View {
        NavigationStack {
            Group {
                if appointments.isEmpty {
                    emptyState
                } else {
                    List {
                        if !upcoming.isEmpty {
                            Section("Upcoming") {
                                ForEach(upcoming) { appointment in
                                    NavigationLink {
                                        AppointmentDetailView(appointment: appointment)
                                    } label: {
                                        row(appointment)
                                    }
                                }
                                .onDelete { delete($0, from: upcoming) }
                            }
                        }
                        if !past.isEmpty {
                            Section("Past") {
                                ForEach(past) { appointment in
                                    NavigationLink {
                                        AppointmentDetailView(appointment: appointment)
                                    } label: {
                                        row(appointment)
                                    }
                                }
                                .onDelete { delete($0, from: past) }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Appointments")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                            .accessibilityLabel("Add appointment")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddAppointmentView()
            }
        }
    }

    private func row(_ appointment: Appointment) -> some View {
        HStack(spacing: 12) {
            Image(systemName: appointment.isCompleted ? "checkmark.circle.fill" : "calendar")
                .foregroundColor(appointment.isCompleted ? .mbGood : .mbPrimary)
                .font(.title3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Dr. \(appointment.doctorName)")
                    .font(.headline)
                if !appointment.specialty.isEmpty {
                    Text(appointment.specialty)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Text(appointment.date.mbDateTime())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func delete(_ offsets: IndexSet, from list: [Appointment]) {
        for index in offsets {
            apptViewModel.deleteAppointment(list[index], in: context)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar")
                .font(.system(size: 64))
                .foregroundColor(.mbPrimary.opacity(0.6))
                .accessibilityHidden(true)
            Text("No appointments yet")
                .font(.title2.weight(.semibold))
            Text("Add your next doctor visit to prepare a summary.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showingAdd = true
            } label: {
                Text("Add appointment")
            }
            .mbPrimaryButton()
            .padding(.horizontal, 32)
        }
        .padding()
    }
}
