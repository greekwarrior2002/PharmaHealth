import SwiftUI
import SwiftData

struct AddSymptomView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Medication> { $0.isActive == true })
    private var medications: [Medication]

    @State private var feeling: Int = 3
    @State private var selectedSymptoms: Set<String> = []
    @State private var customSymptom: String = ""
    @State private var notes: String = ""
    @State private var relatedMedicationID: UUID?
    @State private var showingCustomEntry = false

    private let presetSymptoms = [
        "Headache", "Nausea", "Dizziness", "Fatigue",
        "Shortness of breath", "Chest pain", "Stomach upset",
        "Swelling", "Rash"
    ]

    private let feelingLabels = ["Very bad", "Bad", "Okay", "Good", "Very good"]
    private let feelingEmojis = ["😣", "🙁", "😐", "🙂", "😄"]

    var body: some View {
        NavigationStack {
            Form {
                Section("How are you feeling?") {
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { value in
                            Button {
                                feeling = value
                            } label: {
                                VStack(spacing: 4) {
                                    Text(feelingEmojis[value - 1])
                                        .font(.system(size: 36))
                                    Text(feelingLabels[value - 1])
                                        .font(.caption2)
                                }
                                .frame(maxWidth: .infinity, minHeight: 72)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(feeling == value ? Color.mbPrimary.opacity(0.15) : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(feeling == value ? Color.mbPrimary : Color.secondary.opacity(0.3), lineWidth: 2)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(feelingLabels[value - 1])
                            .accessibilityAddTraits(feeling == value ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Symptoms") {
                    let columns = [GridItem(.adaptive(minimum: 120), spacing: 8)]
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(presetSymptoms + Array(selectedSymptoms.subtracting(presetSymptoms)), id: \.self) { symptom in
                            chip(symptom)
                        }
                        Button {
                            showingCustomEntry = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("Add custom")
                            }
                            .font(.subheadline.weight(.semibold))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.mbPrimary)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.mbPrimary, style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                            )
                        }
                        .accessibilityLabel("Add custom symptom")
                    }
                }

                Section("Notes (optional)") {
                    TextField("How are you feeling overall?", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if !medications.isEmpty {
                    Section("Related medication (optional)") {
                        Picker("Medication", selection: $relatedMedicationID) {
                            Text("None").tag(UUID?.none)
                            ForEach(medications) { med in
                                Text(med.name).tag(Optional(med.id))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Log Symptoms")
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
            .alert("Add custom symptom", isPresented: $showingCustomEntry) {
                TextField("Symptom", text: $customSymptom)
                Button("Add") {
                    let trimmed = customSymptom.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        selectedSymptoms.insert(trimmed)
                    }
                    customSymptom = ""
                }
                Button("Cancel", role: .cancel) { customSymptom = "" }
            }
        }
    }

    private func chip(_ symptom: String) -> some View {
        Button {
            if selectedSymptoms.contains(symptom) {
                selectedSymptoms.remove(symptom)
            } else {
                selectedSymptoms.insert(symptom)
            }
        } label: {
            Text(symptom)
                .font(.subheadline.weight(.semibold))
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .frame(maxWidth: .infinity)
                .foregroundColor(selectedSymptoms.contains(symptom) ? .white : .mbPrimary)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(selectedSymptoms.contains(symptom) ? Color.mbPrimary : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.mbPrimary, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symptom)
        .accessibilityAddTraits(selectedSymptoms.contains(symptom) ? .isSelected : [])
    }

    private func save() {
        let med = relatedMedicationID.flatMap { id in
            medications.first(where: { $0.id == id })
        }
        let log = SymptomLog(
            date: .now,
            overallFeeling: feeling,
            symptoms: Array(selectedSymptoms),
            notes: notes,
            relatedMedication: med
        )
        context.insert(log)
        try? context.save()
        dismiss()
    }
}
