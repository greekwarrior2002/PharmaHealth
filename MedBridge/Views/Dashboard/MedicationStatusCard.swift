import SwiftUI

struct MedicationStatusCard: View {
    let medication: Medication

    private var days: Int? {
        RefillCalculator.daysUntilRunOut(medication: medication)
    }

    private var urgency: RefillCalculator.UrgencyLevel {
        RefillCalculator.urgency(for: medication)
    }

    private var urgencyColor: Color {
        switch urgency {
        case .good: return .mbGood
        case .warning: return .mbUrgent
        case .urgent: return .mbDanger
        case .unknown: return .secondary
        }
    }

    private var urgencyIcon: String {
        switch urgency {
        case .good: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .urgent: return "exclamationmark.octagon.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: urgencyIcon)
                    .foregroundColor(urgencyColor)
                    .accessibilityHidden(true)
                Text(medication.name)
                    .font(.headline)
                    .lineLimit(1)
            }

            Text(medication.dosage)
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let days = days {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(days) days left")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(urgencyColor)
                    Text("\(medication.quantityOnHand) pills")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("As needed")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if !medication.pharmacyPhone.isEmpty,
               let url = medication.pharmacyPhone.phoneURL {
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Image(systemName: "phone.fill")
                        Text("Call \(medication.pharmacyName)")
                            .lineLimit(1)
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundColor(.mbPrimary)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.mbPrimary, lineWidth: 1.5)
                    )
                }
                .accessibilityLabel("Call \(medication.pharmacyName)")
            }
        }
        .frame(width: 220, alignment: .leading)
        .mbCard()
        .accessibilityElement(children: .combine)
    }
}
