import WidgetKit
import SwiftUI
import SwiftData

// TODO: Match the App Group identifier configured in entitlements.
private let appGroupIdentifier = "group.com.yourdomain.pharmahealth"

struct PharmaHealthEntry: TimelineEntry {
    let date: Date
    let topMedications: [WidgetMedication]
    let nextAppointment: WidgetAppointment?
}

struct WidgetMedication: Identifiable {
    let id: UUID
    let name: String
    let daysLeft: Int?
    let quantityOnHand: Int
}

struct WidgetAppointment: Identifiable {
    let id: UUID
    let doctorName: String
    let date: Date
}

struct PharmaHealthProvider: TimelineProvider {
    func placeholder(in context: Context) -> PharmaHealthEntry {
        PharmaHealthEntry(
            date: .now,
            topMedications: [
                WidgetMedication(id: UUID(), name: "Lisinopril", daysLeft: 5, quantityOnHand: 5),
                WidgetMedication(id: UUID(), name: "Metformin", daysLeft: 12, quantityOnHand: 12)
            ],
            nextAppointment: WidgetAppointment(id: UUID(), doctorName: "Singh", date: .now.addingTimeInterval(86400 * 3))
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PharmaHealthEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PharmaHealthEntry>) -> Void) {
        let entry = loadEntry()
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 3, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func loadEntry() -> PharmaHealthEntry {
        let schema = Schema([
            Medication.self,
            DoseEntry.self,
            SymptomLog.self,
            Appointment.self,
            CaregiverProfile.self
        ])
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent("PharmaHealth.store"),
              let container = try? ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, url: url)
              ) else {
            return PharmaHealthEntry(date: .now, topMedications: [], nextAppointment: nil)
        }
        let context = ModelContext(container)

        let medDescriptor = FetchDescriptor<Medication>(
            predicate: #Predicate { $0.isActive == true }
        )
        let allMeds = (try? context.fetch(medDescriptor)) ?? []
        let widgetMeds = allMeds
            .map { med in
                WidgetMedication(
                    id: med.id,
                    name: med.name,
                    daysLeft: RefillCalculator.daysUntilRunOut(medication: med),
                    quantityOnHand: med.quantityOnHand
                )
            }
            .sorted { lhs, rhs in
                (lhs.daysLeft ?? Int.max) < (rhs.daysLeft ?? Int.max)
            }

        let now = Date()
        var apptDescriptor = FetchDescriptor<Appointment>(
            predicate: #Predicate { !$0.isCompleted && $0.date >= now },
            sortBy: [SortDescriptor(\.date)]
        )
        apptDescriptor.fetchLimit = 1
        let nextAppt = try? context.fetch(apptDescriptor).first

        let widgetAppt = nextAppt.map {
            WidgetAppointment(id: $0.id, doctorName: $0.doctorName, date: $0.date)
        }

        return PharmaHealthEntry(
            date: .now,
            topMedications: Array(widgetMeds.prefix(2)),
            nextAppointment: widgetAppt
        )
    }
}

struct PharmaHealthWidgetEntryView: View {
    var entry: PharmaHealthProvider.Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall: smallView
        default: mediumView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "pills.fill")
                Text("PharmaHealth")
                    .font(.caption.weight(.semibold))
            }
            .foregroundColor(.mbPrimary)

            if let med = entry.topMedications.first {
                Text(med.name)
                    .font(.headline)
                    .lineLimit(1)
                if let days = med.daysLeft {
                    Text("\(days) days left")
                        .font(.title3.weight(.bold))
                        .foregroundColor(daysColor(days))
                }
                Text("\(med.quantityOnHand) pills")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("No medications")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding()
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "pills.fill")
                Text("PharmaHealth")
                    .font(.caption.weight(.semibold))
            }
            .foregroundColor(.mbPrimary)

            if entry.topMedications.isEmpty {
                Text("No medications")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(entry.topMedications) { med in
                    HStack {
                        Text(med.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Spacer()
                        if let days = med.daysLeft {
                            Text("\(days)d")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(daysColor(days))
                        } else {
                            Text("PRN")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            if let appt = entry.nextAppointment {
                Divider()
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.mbPrimary)
                    Text("Dr. \(appt.doctorName)")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text(appt.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding()
    }

    private func daysColor(_ days: Int) -> Color {
        if days <= 7 { return .mbDanger }
        if days <= 13 { return .mbUrgent }
        return .mbGood
    }
}

@main
struct PharmaHealthWidget: Widget {
    let kind: String = "PharmaHealthWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PharmaHealthProvider()) { entry in
            PharmaHealthWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("PharmaHealth")
        .description("See your most urgent medication and next appointment.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
