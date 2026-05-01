import SwiftUI
import SwiftData

struct EditMedicationView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Bindable var medication: Medication

    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Medication") {
                    TextField("Name", text: $medication.name)
                    TextField("Dosage", text: $medication.dosage)
                    Picker("Frequency", selection: Binding(
                        get: { medication.frequency },
                        set: { medication.frequency = $0 }
                    )) {
                        ForEach(DoseFrequency.allCases) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                }

                Section("Supply") {
                    Stepper(value: $medication.quantityOnHand, in: 0...500) {
                        HStack {
                            Text("On hand")
                            Spacer()
                            Text("\(medication.quantityOnHand) pills")
                                .foregroundColor(.secondary)
                        }
                    }
                    Stepper(value: $medication.refillQuantity, in: 1...500, step: 30) {
                        HStack {
                            Text("Refill quantity")
                            Spacer()
                            Text("\(medication.refillQuantity) pills")
                                .foregroundColor(.secondary)
                        }
                    }
                    DatePicker(
                        "Last fill date",
                        selection: $medication.lastFillDate,
                        displayedComponents: .date
                    )
                }

                Section("Pharmacy") {
                    TextField("Pharmacy name", text: $medication.pharmacyName)
                    TextField("Pharmacy phone", text: $medication.pharmacyPhone)
                        .keyboardType(.phonePad)
                }

                Section("Notes") {
                    TextField("Prescribed by", text: $medication.prescribedBy)
                    TextField("Notes", text: $medication.notes, axis: .vertical)
                        .lineLimit(3...6)
                    Toggle("Active", isOn: $medication.isActive)
                }
            }
            .navigationTitle("Edit Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
            .alert("Cannot save", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func save() {
        do {
            try context.save()
            NotificationManager.shared.scheduleRefillReminder(for: medication)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
