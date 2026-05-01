import SwiftUI
import SwiftData

struct DoseLogView: View {
    let medication: Medication
    @State private var medViewModel = MedicationViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(medViewModel.doseLog(for: medication)) { dose in
                    DoseEntryRow(dose: dose)
                }
                if medication.doseLog.isEmpty {
                    Text("No doses logged yet.")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding()
        }
        .background(Color.mbBackground.ignoresSafeArea())
        .navigationTitle("Dose Log")
        .navigationBarTitleDisplayMode(.inline)
    }
}
