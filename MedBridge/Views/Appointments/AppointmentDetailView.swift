import SwiftUI
import SwiftData

struct AppointmentDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var appointment: Appointment

    @Query private var medications: [Medication]
    @Query private var symptoms: [SymptomLog]
    @Query private var doseLog: [DoseEntry]

    @StateObject private var subscription = SubscriptionManager.shared
    @State private var apptViewModel = AppointmentViewModel()
    @State private var isGenerating = false
    @State private var showingPaywall = false
    @State private var showingPrep = false
    @State private var showingDeleteConfirm = false
    @State private var postNotes = ""
    @State private var newInstructions = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                prepSection
                if appointment.isPast || appointment.isCompleted {
                    postVisitSection
                }
            }
            .padding()
        }
        .background(Color.mbBackground.ignoresSafeArea())
        .navigationTitle("Appointment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showingDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .accessibilityLabel("Delete appointment")
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showingPrep) {
            if let summary = appointment.prepSummary {
                NavigationStack {
                    PrepSummaryView(appointment: appointment, summary: summary)
                }
            }
        }
        .alert("Delete appointment?", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) {
                apptViewModel.deleteAppointment(appointment, in: context)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            postNotes = appointment.postVisitNotes ?? ""
            newInstructions = appointment.newInstructions ?? ""
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Dr. \(appointment.doctorName)")
                .font(.largeTitle.weight(.bold))
            if !appointment.specialty.isEmpty {
                Text(appointment.specialty)
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            Label(appointment.date.mbDateTime(), systemImage: "calendar")
                .font(.body)
                .foregroundColor(.secondary)
            if !appointment.location.isEmpty {
                Label(appointment.location, systemImage: "mappin.and.ellipse")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            if appointment.isCompleted {
                Label("Completed", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.mbGood)
            } else if appointment.isUpcoming {
                Label("Upcoming", systemImage: "clock")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.mbPrimary)
            }
        }
    }

    private var prepSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Visit prep summary")
                .font(.headline)

            if appointment.prepSummary != nil {
                Text("A summary has been generated.")
                    .font(.body)
                    .foregroundColor(.secondary)
                Button {
                    showingPrep = true
                } label: {
                    Label("View prep summary", systemImage: "doc.text")
                }
                .mbPrimaryButton()
            } else {
                Text("Generate a one-page summary of your medications, recent symptoms, and missed doses to share with your doctor.")
                    .font(.body)
                    .foregroundColor(.secondary)
                Button {
                    generate()
                } label: {
                    if isGenerating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Label(
                            subscription.canGeneratePrepSummary
                                ? "Generate prep summary"
                                : "Generate prep summary (Premium)",
                            systemImage: subscription.canGeneratePrepSummary ? "wand.and.stars" : "lock.fill"
                        )
                    }
                }
                .mbPrimaryButton()
                .disabled(isGenerating)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mbCard()
    }

    private func generate() {
        guard subscription.canGeneratePrepSummary else {
            showingPaywall = true
            return
        }
        isGenerating = true
        Task { @MainActor in
            _ = apptViewModel.generatePrep(
                for: appointment,
                medications: medications,
                symptoms: symptoms,
                doseLog: doseLog,
                context: context
            )
            isGenerating = false
            showingPrep = true
        }
    }

    private var postVisitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Post-visit notes")
                .font(.headline)
            TextField("New instructions from your doctor", text: $newInstructions, axis: .vertical)
                .lineLimit(3...8)
                .textFieldStyle(.roundedBorder)
            TextField("Other notes", text: $postNotes, axis: .vertical)
                .lineLimit(3...8)
                .textFieldStyle(.roundedBorder)
            Toggle("Mark as completed", isOn: $appointment.isCompleted)
            Button {
                appointment.postVisitNotes = postNotes
                appointment.newInstructions = newInstructions
                try? context.save()
            } label: {
                Text("Save notes")
            }
            .mbPrimaryButton()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mbCard()
    }
}
