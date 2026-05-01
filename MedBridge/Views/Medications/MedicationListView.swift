import SwiftUI
import SwiftData

struct MedicationListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Medication.name) private var medications: [Medication]
    @State private var medViewModel = MedicationViewModel()
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if medications.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(medications) { medication in
                            NavigationLink {
                                MedicationDetailView(medication: medication)
                            } label: {
                                row(medication)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Medications")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                            .accessibilityLabel("Add medication")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddMedicationView()
            }
        }
    }

    private func row(_ medication: Medication) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "pills.fill")
                .foregroundColor(.mbPrimary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(medication.name)
                    .font(.headline)
                Text("\(medication.dosage) — \(medication.frequency.rawValue)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if let days = RefillCalculator.daysUntilRunOut(medication: medication) {
                Text("\(days)d")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(daysBackground(days))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .accessibilityLabel("\(days) days remaining")
            }
        }
        .padding(.vertical, 6)
    }

    private func daysBackground(_ days: Int) -> Color {
        if days <= 7 { return .mbDanger }
        if days <= 13 { return .mbUrgent }
        return .mbGood
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            medViewModel.deleteMedication(medications[index], in: context)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "pills.fill")
                .font(.system(size: 64))
                .foregroundColor(.mbPrimary.opacity(0.6))
                .accessibilityHidden(true)
            Text("No medications yet")
                .font(.title2.weight(.semibold))
            Text("Tap + to add your first medication.")
                .foregroundColor(.secondary)
            Button {
                showingAdd = true
            } label: {
                Text("Add medication")
            }
            .mbPrimaryButton()
            .padding(.horizontal, 32)
        }
        .padding()
    }
}
