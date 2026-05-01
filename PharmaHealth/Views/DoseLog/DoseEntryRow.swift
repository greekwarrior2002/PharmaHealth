import SwiftUI
import SwiftData

struct DoseEntryRow: View {
    @Environment(\.modelContext) private var context
    let dose: DoseEntry
    @State private var medViewModel = MedicationViewModel()

    private var statusIcon: String {
        switch dose.status {
        case .taken: return "checkmark.circle.fill"
        case .missed: return "xmark.circle.fill"
        case .skipped: return "minus.circle.fill"
        case .upcoming: return "clock"
        }
    }

    private var statusColor: Color {
        switch dose.status {
        case .taken: return .mbGood
        case .missed: return .mbDanger
        case .skipped: return .secondary
        case .upcoming: return .mbPrimary
        }
    }

    private var statusLabel: String {
        switch dose.status {
        case .taken: return "Taken"
        case .missed: return "Missed"
        case .skipped: return "Skipped"
        case .upcoming: return "Upcoming"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .font(.title3)
                .accessibilityLabel(statusLabel)
            VStack(alignment: .leading, spacing: 2) {
                Text(dose.medication?.name ?? "Medication")
                    .font(.headline)
                Text(dose.scheduledDate.formatted(date: .omitted, time: .shortened))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if dose.status == .upcoming || dose.status == .missed {
                HStack(spacing: 8) {
                    Button {
                        if let med = dose.medication {
                            dose.takenDate = .now
                            dose.skipped = false
                            if med.quantityOnHand > 0 {
                                med.quantityOnHand -= 1
                            }
                            try? context.save()
                            Task { @MainActor in
                                NotificationManager.shared.scheduleRefillReminder(for: med)
                            }
                        }
                    } label: {
                        Text("Taken")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .foregroundColor(.white)
                            .background(Color.mbGood)
                            .cornerRadius(10)
                    }
                    .accessibilityLabel("Mark \(dose.medication?.name ?? "medication") as taken")

                    Button {
                        dose.skipped = true
                        try? context.save()
                    } label: {
                        Text("Skip")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .foregroundColor(.mbDanger)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.mbDanger, lineWidth: 1.5)
                            )
                    }
                    .accessibilityLabel("Skip \(dose.medication?.name ?? "medication") dose")
                }
            } else {
                Text(statusLabel)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .mbCard()
    }
}
