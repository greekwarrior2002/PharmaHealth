import SwiftUI
import SwiftData

struct MedicationDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var medication: Medication

    @State private var medViewModel = MedicationViewModel()
    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false
    @State private var showingRefill = false
    @State private var refillAmount = 90

    private var days: Int? {
        RefillCalculator.daysUntilRunOut(medication: medication)
    }

    private var runOutDate: Date? {
        RefillCalculator.estimatedRunOutDate(medication: medication)
    }

    private var callDate: Date? {
        RefillCalculator.refillCallReminderDate(medication: medication)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                refillStatusCard
                quickActions
                doseLogGrid
            }
            .padding()
        }
        .background(Color.mbBackground.ignoresSafeArea())
        .navigationTitle(medication.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingEdit = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .accessibilityLabel("More options")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            EditMedicationView(medication: medication)
        }
        .alert("Delete medication?", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) {
                medViewModel.deleteMedication(medication, in: context)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all dose history for \(medication.name).")
        }
        .sheet(isPresented: $showingRefill) {
            refillSheet
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(medication.name)
                .font(.largeTitle.weight(.bold))
            Text("\(medication.dosage) — \(medication.frequency.rawValue)")
                .font(.title3)
                .foregroundColor(.secondary)
            if !medication.prescribedBy.isEmpty {
                Text("Prescribed by \(medication.prescribedBy)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var refillStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Refill status")
                .font(.headline)
            if let days = days {
                HStack {
                    Text("\(days) days left")
                        .font(.title.weight(.bold))
                        .foregroundColor(daysColor(days))
                    Spacer()
                    Text("\(medication.quantityOnHand) pills")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                if let runOut = runOutDate {
                    Label("Estimated run-out: \(runOut.mbShort())", systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                if let call = callDate, call > .now {
                    Label("We'll remind you on \(call.mbShort())", systemImage: "bell")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("As needed — no refill calculation")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mbCard()
    }

    private func daysColor(_ days: Int) -> Color {
        if days <= 7 { return .mbDanger }
        if days <= 13 { return .mbUrgent }
        return .mbGood
    }

    private var quickActions: some View {
        VStack(spacing: 12) {
            if !medication.pharmacyPhone.isEmpty,
               let url = medication.pharmacyPhone.phoneURL {
                Link(destination: url) {
                    Label("Call \(medication.pharmacyName)", systemImage: "phone.fill")
                }
                .mbPrimaryButton()
                .accessibilityLabel("Call \(medication.pharmacyName)")
            }
            Button {
                refillAmount = medication.refillQuantity
                showingRefill = true
            } label: {
                Label("Mark as refilled", systemImage: "arrow.clockwise")
            }
            .font(.headline)
            .frame(minHeight: 52)
            .frame(maxWidth: .infinity)
            .foregroundColor(.mbPrimary)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.mbPrimary, lineWidth: 1.5)
            )
        }
    }

    private var doseLogGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 14 days")
                .font(.headline)
            let entries = medViewModel.doseLog(for: medication, days: 14)
            if entries.isEmpty {
                Text("No doses logged yet.")
                    .font(.body)
                    .foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                    ForEach(entries) { dose in
                        Circle()
                            .fill(color(for: dose))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Text(dayString(dose.scheduledDate))
                                    .font(.caption2)
                                    .foregroundColor(.white)
                            )
                            .accessibilityLabel("\(dose.scheduledDate.mbShort()): \(label(for: dose))")
                    }
                }
            }
            NavigationLink {
                DoseLogView(medication: medication)
            } label: {
                Text("See full history")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.mbPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mbCard()
    }

    private func color(for dose: DoseEntry) -> Color {
        switch dose.status {
        case .taken: return .mbGood
        case .missed: return .mbDanger
        case .skipped: return .secondary
        case .upcoming: return .mbPrimary
        }
    }

    private func label(for dose: DoseEntry) -> String {
        switch dose.status {
        case .taken: return "Taken"
        case .missed: return "Missed"
        case .skipped: return "Skipped"
        case .upcoming: return "Upcoming"
        }
    }

    private func dayString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }

    private var refillSheet: some View {
        NavigationStack {
            Form {
                Section("How many pills?") {
                    Stepper(value: $refillAmount, in: 1...500, step: 1) {
                        HStack {
                            Text("Pills")
                            Spacer()
                            Text("\(refillAmount)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Section {
                    Text("This sets your current pill count and resets the refill timer.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Mark as refilled")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showingRefill = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        medViewModel.markRefilled(medication, quantity: refillAmount, in: context)
                        showingRefill = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
