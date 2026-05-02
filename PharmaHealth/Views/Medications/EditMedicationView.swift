import SwiftUI
import SwiftData

struct EditMedicationView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Bindable var medication: Medication

    @State private var doseAmountText: String = ""
    @State private var doseUnit: String = ""
    @State private var showingPharmacyPicker = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Medication") {
                    TextField("Name", text: $medication.name)
                    Picker("Form", selection: Binding(
                        get: { medication.form },
                        set: { medication.form = $0 }
                    )) {
                        ForEach(MedicationForm.allCases) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    Picker("Frequency", selection: Binding(
                        get: { medication.frequency },
                        set: { medication.frequency = $0 }
                    )) {
                        ForEach(DoseFrequency.allCases) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                }

                Section("Dose") {
                    HStack {
                        TextField("Amount", text: $doseAmountText)
                            .keyboardType(.decimalPad)
                            .onChange(of: doseAmountText) { _, new in
                                let filtered = new.filter { $0.isNumber || $0 == "." }
                                if filtered != new { doseAmountText = filtered }
                            }
                        TextField("Unit (e.g., mg, mL)", text: $doseUnit)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    TextField("Free-text dosage", text: $medication.dosage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Section {
                    QuantityStepperField(
                        title: "On hand",
                        value: $medication.quantityOnHand,
                        range: 0...5000,
                        step: 1,
                        unitLabel: medication.form.unitLabel
                    )
                    QuantityStepperField(
                        title: "Refill quantity",
                        value: $medication.refillQuantity,
                        range: 1...5000,
                        step: 1,
                        unitLabel: medication.form.unitLabel
                    )
                    DatePicker(
                        "Last fill date",
                        selection: $medication.lastFillDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                } header: {
                    Text("Supply")
                } footer: {
                    Text("On-hand updates the refill estimate; refill quantity is what the pharmacy gives you per fill.")
                        .font(.footnote)
                }

                Section("Pharmacy") {
                    Button {
                        showingPharmacyPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "cross.case.fill")
                                .foregroundColor(.mbPrimary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(medication.pharmacyName.isEmpty ? "Choose pharmacy" : medication.pharmacyName)
                                    .foregroundColor(medication.pharmacyName.isEmpty ? .secondary : .primary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

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
            .sheet(isPresented: $showingPharmacyPicker) {
                PharmacyPickerView(
                    initialName: medication.pharmacyName,
                    initialPhone: medication.pharmacyPhone
                ) { pick in
                    medication.pharmacyName = pick.name
                    if !pick.phone.isEmpty { medication.pharmacyPhone = pick.phone }
                    upsertPharmacyRecord(pick)
                }
            }
            .task {
                if let amt = medication.doseAmount {
                    doseAmountText = amt.truncatingRemainder(dividingBy: 1) == 0
                        ? String(Int(amt)) : String(amt)
                }
                if let unit = medication.doseUnit {
                    doseUnit = unit
                }
            }
        }
    }

    private func upsertPharmacyRecord(_ pick: PharmacySearchResult) {
        let descriptor = FetchDescriptor<Pharmacy>()
        if let existing = (try? context.fetch(descriptor))?.first(where: {
            $0.name == pick.name && $0.address == pick.address
        }) {
            medication.pharmacyID = existing.id
            if !pick.phone.isEmpty { existing.phone = pick.phone }
        } else {
            let newPharmacy = Pharmacy(
                name: pick.name,
                address: pick.address,
                phone: pick.phone,
                latitude: pick.coordinate?.latitude,
                longitude: pick.coordinate?.longitude
            )
            context.insert(newPharmacy)
            medication.pharmacyID = newPharmacy.id
        }
        try? context.save()
    }

    private func save() {
        // Sync structured dose fields back into the model. Keep the legacy
        // `dosage` text in sync when the user typed an amount + unit.
        let trimmedUnit = doseUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        let amount = Double(doseAmountText)
        medication.doseAmount = amount
        medication.doseUnit = trimmedUnit.isEmpty ? nil : trimmedUnit
        if let amount, !trimmedUnit.isEmpty {
            let formatted = amount.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(amount)) : String(amount)
            medication.dosage = "\(formatted) \(trimmedUnit)"
        }

        // Defensive clamping.
        if medication.quantityOnHand < 0 { medication.quantityOnHand = 0 }
        if medication.refillQuantity < 1 { medication.refillQuantity = 1 }

        do {
            try context.save()
            NotificationManager.shared.scheduleRefillReminder(for: medication)
            MBHaptics.success()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
