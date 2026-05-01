import SwiftUI
import SwiftData

struct SymptomLogView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SymptomLog.date, order: .reverse)
    private var logs: [SymptomLog]

    @State private var showingAdd = false

    private struct WeekGroup: Identifiable {
        let id: Date
        let label: String
        let entries: [SymptomLog]
    }

    private var groupedByWeek: [WeekGroup] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: logs) { log in
            calendar.dateInterval(of: .weekOfYear, for: log.date)?.start ?? log.date
        }
        return groups
            .sorted(by: { $0.key > $1.key })
            .map { (start, entries) in
                let f = DateFormatter()
                f.dateFormat = "MMM d"
                let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
                let label = "\(f.string(from: start)) – \(f.string(from: end))"
                return WeekGroup(
                    id: start,
                    label: label,
                    entries: entries.sorted(by: { $0.date > $1.date })
                )
            }
    }

    var body: some View {
        NavigationStack {
            Group {
                if logs.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(groupedByWeek) { group in
                            Section(group.label) {
                                ForEach(group.entries) { log in
                                    row(log)
                                }
                                .onDelete { offsets in
                                    delete(offsets: offsets, from: group.entries)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Symptom Log")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                            .accessibilityLabel("Log symptoms")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddSymptomView()
            }
        }
    }

    private func row(_ log: SymptomLog) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(log.feelingEmoji)
                .font(.system(size: 32))
                .accessibilityLabel(log.feelingLabel)
            VStack(alignment: .leading, spacing: 4) {
                Text(log.date.mbDateTime())
                    .font(.headline)
                if !log.symptoms.isEmpty {
                    Text(log.symptoms.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                if !log.notes.isEmpty {
                    Text(log.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func delete(offsets: IndexSet, from entries: [SymptomLog]) {
        for index in offsets {
            context.delete(entries[index])
        }
        try? context.save()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 64))
                .foregroundColor(.mbPrimary.opacity(0.6))
                .accessibilityHidden(true)
            Text("No symptoms logged")
                .font(.title2.weight(.semibold))
            Text("Track how you feel each day to share with your doctor.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showingAdd = true
            } label: {
                Text("Log how you're feeling")
            }
            .mbPrimaryButton()
            .padding(.horizontal, 32)
        }
        .padding()
    }
}
