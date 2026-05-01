import SwiftUI
import SwiftData

struct AddMedicationView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Medication> { $0.isActive == true })
    private var activeMedications: [Medication]

    @StateObject private var subscription = SubscriptionManager.shared

    @State private var name = ""
    @State private var dosage = ""
    @State private var frequency: DoseFrequency = .oncedaily
    @State private var quantityOnHand = 30
    @State private var refillQuantity = 90
    @State private var pharmacyName = ""
    @State private var pharmacyPhone = ""
    @State private var lastFillDate = Date()
    @State private var prescribedBy = ""
    @State private var notes = ""

    @State private var showingPaywall = false
    @State private var showingNameSuggestions = false
    @State private var errorMessage: String?

    private var nameSuggestions: [String] {
        guard !name.isEmpty else { return [] }
        return CommonMedications.names
            .filter { $0.lowercased().hasPrefix(name.lowercased()) && $0.lowercased() != name.lowercased() }
            .prefix(5)
            .map { $0 }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !dosage.trimmingCharacters(in: .whitespaces).isEmpty &&
        !pharmacyName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Medication") {
                    TextField("Name (e.g., Lisinopril)", text: $name)
                        .textInputAutocapitalization(.words)
                    if !nameSuggestions.isEmpty {
                        ForEach(nameSuggestions, id: \.self) { suggestion in
                            Button(suggestion) { name = suggestion }
                                .foregroundColor(.mbPrimary)
                        }
                    }
                    TextField("Dosage (e.g., 10mg)", text: $dosage)
                    Picker("Frequency", selection: $frequency) {
                        ForEach(DoseFrequency.allCases) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                }

                Section("Supply") {
                    Stepper(value: $quantityOnHand, in: 0...500) {
                        HStack {
                            Text("On hand")
                            Spacer()
                            Text("\(quantityOnHand) pills")
                                .foregroundColor(.secondary)
                        }
                    }
                    Stepper(value: $refillQuantity, in: 1...500, step: 30) {
                        HStack {
                            Text("Refill quantity")
                            Spacer()
                            Text("\(refillQuantity) pills")
                                .foregroundColor(.secondary)
                        }
                    }
                    DatePicker("Last fill date", selection: $lastFillDate, displayedComponents: .date)
                }

                Section("Pharmacy") {
                    TextField("Pharmacy name", text: $pharmacyName)
                    TextField("Pharmacy phone (optional)", text: $pharmacyPhone)
                        .keyboardType(.phonePad)
                }

                Section("Notes (optional)") {
                    TextField("Prescribed by", text: $prescribedBy)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
            .alert("Cannot save", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
    }

    private func save() {
        let activeCount = activeMedications.count
        if !subscription.canAddMoreMedications(currentActiveCount: activeCount) {
            showingPaywall = true
            return
        }

        let medication = Medication(
            name: name.trimmingCharacters(in: .whitespaces),
            dosage: dosage.trimmingCharacters(in: .whitespaces),
            frequency: frequency,
            quantityOnHand: quantityOnHand,
            refillQuantity: refillQuantity,
            pharmacyName: pharmacyName.trimmingCharacters(in: .whitespaces),
            pharmacyPhone: pharmacyPhone,
            lastFillDate: lastFillDate,
            prescribedBy: prescribedBy,
            notes: notes
        )
        context.insert(medication)
        do {
            try context.save()
            NotificationManager.shared.scheduleRefillReminder(for: medication)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
