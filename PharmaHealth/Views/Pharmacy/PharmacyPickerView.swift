import SwiftUI

/// Sheet that lets the user search for a nearby pharmacy or enter one
/// manually. The caller passes a closure that receives the chosen
/// `PharmacySearchResult` (or `nil` for manual entry handled inline).
struct PharmacyPickerView: View {
    @Environment(\.dismiss) private var dismiss

    /// Initial values, used when editing an existing medication's pharmacy.
    let initialName: String
    let initialPhone: String

    /// Optional default pharmacy shown at the top so the user can pick it
    /// with one tap. Passed in as a lightweight `PharmacySearchResult` so the
    /// picker stays free of SwiftData fetches.
    let defaultPharmacy: PharmacySearchResult?

    /// Called when the user picks/saves a pharmacy.
    let onSelect: (PharmacySearchResult) -> Void

    @StateObject private var service = PharmacySearchService()
    @State private var query: String = ""
    @State private var manualName: String = ""
    @State private var manualAddress: String = ""
    @State private var manualPhone: String = ""

    init(
        initialName: String = "",
        initialPhone: String = "",
        defaultPharmacy: PharmacySearchResult? = nil,
        onSelect: @escaping (PharmacySearchResult) -> Void
    ) {
        self.initialName = initialName
        self.initialPhone = initialPhone
        self.defaultPharmacy = defaultPharmacy
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            List {
                defaultSection
                searchSection
                resultsSection
                manualSection
            }
            .navigationTitle("Choose Pharmacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                manualName = initialName
                manualPhone = initialPhone
                // Don't auto-request location — wait for explicit user action.
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var defaultSection: some View {
        if let def = defaultPharmacy {
            Section {
                Button {
                    onSelect(def)
                    MBHaptics.success()
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.mbPrimary)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(def.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                defaultBadge
                            }
                            if !def.address.isEmpty {
                                Text(def.address)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Use default pharmacy \(def.name)")
            } header: {
                Text("Default Pharmacy")
            }
        }
    }

    private var defaultBadge: some View {
        Text("Default")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(Color.mbPrimary.opacity(0.15))
            )
            .foregroundColor(.mbPrimary)
            .accessibilityLabel("Default pharmacy")
    }

    private var searchSection: some View {
        Section {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
                TextField("Search by name or address", text: $query)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await service.searchByText(query) }
                    }
                if service.isSearching {
                    ProgressView().controlSize(.small)
                }
            }

            Button {
                Task { await service.searchNearby() }
            } label: {
                Label("Find pharmacies near me", systemImage: "location.fill")
            }
            .buttonStyle(.mbPrimary)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))

            if service.authorization == .denied || service.authorization == .restricted {
                Text("Location is turned off. You can still search by name or address above, or open Settings to allow location access.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.footnote)
            }
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        if !service.results.isEmpty {
            Section("Results") {
                ForEach(service.results) { result in
                    Button {
                        onSelect(result)
                        MBHaptics.success()
                        dismiss()
                    } label: {
                        resultRow(result)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            }
        } else if let error = service.lastError {
            Section {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var manualSection: some View {
        Section("Or enter manually") {
            TextField("Pharmacy name", text: $manualName)
                .textInputAutocapitalization(.words)
            TextField("Address (optional)", text: $manualAddress)
            TextField("Phone (optional)", text: $manualPhone)
                .keyboardType(.phonePad)
            Button {
                let trimmed = manualName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                let result = PharmacySearchResult(
                    name: trimmed,
                    address: manualAddress.trimmingCharacters(in: .whitespacesAndNewlines),
                    phone: manualPhone.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                onSelect(result)
                MBHaptics.success()
                dismiss()
            } label: {
                Text("Use this pharmacy")
            }
            .buttonStyle(.mbSecondary)
            .disabled(manualName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        }
    }

    private func resultRow(_ r: PharmacySearchResult) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "cross.case.fill")
                .foregroundColor(.mbPrimary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(r.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                if !r.address.isEmpty {
                    Text(r.address)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            if let dist = r.displayDistance {
                Text(dist)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
