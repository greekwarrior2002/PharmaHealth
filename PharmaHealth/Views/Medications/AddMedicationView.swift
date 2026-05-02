import SwiftUI
import SwiftData
import CoreLocation

struct AddMedicationView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Medication> { $0.isActive == true })
    private var activeMedications: [Medication]

    @StateObject private var subscription = SubscriptionManager.shared
    @EnvironmentObject private var pharmacyPreferences: PharmacyPreferencesService

    @State private var name = ""
    @State private var doseAmountText: String = "10"
    @State private var doseUnit: String = MedicationForm.tablet.defaultDoseUnit
    @State private var form: MedicationForm = .tablet
    @State private var frequency: DoseFrequency = .oncedaily
    @State private var quantityOnHand: Int = 30
    @State private var refillQuantity: Int = 90
    @State private var pharmacyName = ""
    @State private var pharmacyAddress = ""
    @State private var pharmacyPhone = ""
    @State private var pharmacyID: UUID?
    @State private var lastFillDate = Date()
    @State private var prescribedBy = ""
    @State private var notes = ""

    @State private var showingPaywall = false
    @State private var showingPharmacyPicker = false
    @State private var showingDefaultPrompt = false
    @State private var didPrefillFromDefault = false
    @State private var errorMessage: String?

    private var nameSuggestions: [String] {
        guard !name.isEmpty else { return [] }
        let prefix = name.lowercased()
        return CommonMedications.names
            .filter { $0.lowercased().hasPrefix(prefix) && $0.lowercased() != prefix }
            .prefix(5)
            .map { $0 }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !pharmacyName.trimmingCharacters(in: .whitespaces).isEmpty &&
        quantityOnHand >= 0 &&
        refillQuantity >= 1
    }

    var body: some View {
        NavigationStack {
            Form {
                medicationSection
                doseSection
                supplySection
                pharmacySection
                notesSection
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
            .sheet(isPresented: $showingPaywall) { PaywallView() }
            .sheet(isPresented: $showingPharmacyPicker) {
                PharmacyPickerView(
                    initialName: pharmacyName,
                    initialPhone: pharmacyPhone,
                    defaultPharmacy: defaultPharmacyResult()
                ) { pick in
                    apply(pickedPharmacy: pick)
                }
            }
            .confirmationDialog(
                "Set as default pharmacy?",
                isPresented: $showingDefaultPrompt,
                titleVisibility: .visible
            ) {
                Button("Use & set as default") {
                    if let pharmacyID, let pharmacy = fetchPharmacy(id: pharmacyID) {
                        pharmacyPreferences.setDefault(pharmacy, in: context)
                    }
                }
                Button("Use only for this medication", role: .cancel) { }
            } message: {
                Text("You can change this any time from Settings → My Pharmacy.")
            }
            .onAppear { prefillFromDefaultIfNeeded() }
        }
    }

    // MARK: - Default pharmacy helpers

    private func defaultPharmacyResult() -> PharmacySearchResult? {
        guard let pharmacy = pharmacyPreferences.defaultPharmacy(in: context) else {
            return nil
        }
        let coord = pharmacy.latitude.flatMap { lat in
            pharmacy.longitude.map { CLLocationCoordinate2D(latitude: lat, longitude: $0) }
        }
        return PharmacySearchResult(
            id: pharmacy.id,
            name: pharmacy.name,
            address: pharmacy.address,
            phone: pharmacy.phone,
            coordinate: coord
        )
    }

    private func prefillFromDefaultIfNeeded() {
        guard !didPrefillFromDefault else { return }
        guard pharmacyName.isEmpty,
              pharmacyAddress.isEmpty,
              pharmacyPhone.isEmpty,
              pharmacyID == nil else { return }
        guard let pharmacy = pharmacyPreferences.defaultPharmacy(in: context) else { return }
        pharmacyName = pharmacy.name
        pharmacyAddress = pharmacy.address
        pharmacyPhone = pharmacy.phone
        pharmacyID = pharmacy.id
        didPrefillFromDefault = true
    }

    private func fetchPharmacy(id: UUID) -> Pharmacy? {
        let descriptor = FetchDescriptor<Pharmacy>(
            predicate: #Predicate { $0.id == id }
        )
        return try? context.fetch(descriptor).first
    }

    // MARK: - Sections

    private var medicationSection: some View {
        Section("Medication") {
            TextField("Name (e.g., Lisinopril)", text: $name)
                .textInputAutocapitalization(.words)
            if !nameSuggestions.isEmpty {
                ForEach(nameSuggestions, id: \.self) { suggestion in
                    Button {
                        name = suggestion
                        MBHaptics.selection()
                    } label: {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            Text(suggestion)
                                .foregroundColor(.mbPrimary)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            Picker("Form", selection: $form) {
                ForEach(MedicationForm.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .onChange(of: form) { _, newForm in
                // Adjust the dose unit suggestion when the form changes,
                // unless the user has already typed something custom.
                if doseUnit.isEmpty || MedicationForm.allCases.map(\.defaultDoseUnit).contains(doseUnit) {
                    doseUnit = newForm.defaultDoseUnit
                }
            }
        }
    }

    private var doseSection: some View {
        Section("Dose") {
            HStack {
                TextField("Amount", text: $doseAmountText)
                    .keyboardType(.decimalPad)
                    .onChange(of: doseAmountText) { _, new in
                        // Allow numeric + single decimal point.
                        let filtered = new.filter { $0.isNumber || $0 == "." }
                        if filtered != new { doseAmountText = filtered }
                    }
                TextField("Unit (e.g., mg, mL, puff)", text: $doseUnit)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Picker("Frequency", selection: $frequency) {
                ForEach(DoseFrequency.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }
        }
    }

    private var supplySection: some View {
        Section {
            QuantityStepperField(
                title: "On hand",
                value: $quantityOnHand,
                range: 0...5000,
                step: 1,
                unitLabel: form.unitLabel
            )
            QuantityStepperField(
                title: "Refill quantity",
                value: $refillQuantity,
                range: 1...5000,
                step: 1,
                unitLabel: form.unitLabel
            )
            DatePicker(
                "Last fill date",
                selection: $lastFillDate,
                in: ...Date(),
                displayedComponents: .date
            )
        } header: {
            Text("Supply")
        } footer: {
            Text("On-hand drives refill reminders; refill quantity is what the pharmacy gives you per fill.")
                .font(.footnote)
        }
    }

    private var pharmacySection: some View {
        Section("Pharmacy") {
            Button {
                showingPharmacyPicker = true
            } label: {
                HStack {
                    Image(systemName: "cross.case.fill")
                        .foregroundColor(.mbPrimary)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(pharmacyName.isEmpty ? "Choose pharmacy" : pharmacyName)
                                .foregroundColor(pharmacyName.isEmpty ? .secondary : .primary)
                            if pharmacyPreferences.isDefault(pharmacyID) {
                                Text("Default")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.mbPrimary.opacity(0.15)))
                                    .foregroundColor(.mbPrimary)
                                    .accessibilityLabel("Default pharmacy")
                            }
                        }
                        if !pharmacyAddress.isEmpty {
                            Text(pharmacyAddress)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            TextField("Pharmacy phone (optional)", text: $pharmacyPhone)
                .keyboardType(.phonePad)
        }
    }

    private var notesSection: some View {
        Section("Notes (optional)") {
            TextField("Prescribed by", text: $prescribedBy)
            TextField("Notes", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    // MARK: - Actions

    private func apply(pickedPharmacy: PharmacySearchResult) {
        pharmacyName = pickedPharmacy.name
        pharmacyAddress = pickedPharmacy.address
        if !pickedPharmacy.phone.isEmpty {
            pharmacyPhone = pickedPharmacy.phone
        }

        // Persist a Pharmacy record if it's new (or look up an existing one
        // with the same name + address). This keeps the picker reusable across
        // medications without duplicating identical entries.
        let descriptor = FetchDescriptor<Pharmacy>()
        if let existing = (try? context.fetch(descriptor))?.first(where: {
            $0.name == pickedPharmacy.name && $0.address == pickedPharmacy.address
        }) {
            pharmacyID = existing.id
            if !pickedPharmacy.phone.isEmpty { existing.phone = pickedPharmacy.phone }
        } else {
            let newPharmacy = Pharmacy(
                name: pickedPharmacy.name,
                address: pickedPharmacy.address,
                phone: pickedPharmacy.phone,
                latitude: pickedPharmacy.coordinate?.latitude,
                longitude: pickedPharmacy.coordinate?.longitude
            )
            context.insert(newPharmacy)
            pharmacyID = newPharmacy.id
        }
        try? context.save()

        // If this pharmacy isn't already the default, offer to set it as one.
        // Skip the prompt if it already matches — silent no-op feels best.
        if let id = pharmacyID, pharmacyPreferences.defaultPharmacyID != id {
            showingDefaultPrompt = true
        }
    }

    private func save() {
        let activeCount = activeMedications.count
        if !subscription.canAddMoreMedications(currentActiveCount: activeCount) {
            showingPaywall = true
            return
        }

        // Validate quantities — never allow negative, and refill must be >= 1.
        let qty = max(0, quantityOnHand)
        let refill = max(1, refillQuantity)
        let amount = Double(doseAmountText)
        let trimmedUnit = doseUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        let legacyDosage: String = {
            if let amount, !trimmedUnit.isEmpty {
                let formatted = amount.truncatingRemainder(dividingBy: 1) == 0
                    ? String(Int(amount)) : String(amount)
                return "\(formatted) \(trimmedUnit)"
            }
            return doseAmountText.isEmpty ? trimmedUnit : "\(doseAmountText) \(trimmedUnit)"
        }()

        let medication = Medication(
            name: name.trimmingCharacters(in: .whitespaces),
            dosage: legacyDosage,
            frequency: frequency,
            quantityOnHand: qty,
            refillQuantity: refill,
            pharmacyName: pharmacyName.trimmingCharacters(in: .whitespaces),
            pharmacyPhone: pharmacyPhone,
            lastFillDate: lastFillDate,
            prescribedBy: prescribedBy,
            notes: notes,
            form: form,
            doseAmount: amount,
            doseUnit: trimmedUnit.isEmpty ? nil : trimmedUnit,
            pharmacyID: pharmacyID
        )
        context.insert(medication)
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
