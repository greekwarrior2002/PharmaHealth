import SwiftUI
import SwiftData

/// Overview of recent health data — pulls from HealthKit (when authorized)
/// and from the user's own scanned/entered `HealthReading` records. Designed
/// to refresh on appearance only; we never set up live observers here.
struct HealthOverviewView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var hk = HealthKitService()
    @Query(sort: \HealthReading.date, order: .reverse) private var readings: [HealthReading]

    @State private var showingScanner = false
    @State private var scannerHint: HealthMetricType?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    scanCTA

                    Text("From Apple Health")
                        .font(.title3.weight(.semibold))
                    healthKitGrid

                    if !readings.isEmpty {
                        Text("Your recent scans")
                            .font(.title3.weight(.semibold))
                            .padding(.top, 8)
                        readingsList
                    }

                    NavigationLink {
                        SymptomLogView()
                    } label: {
                        HStack {
                            Image(systemName: "heart.text.square")
                            Text("Symptom & feelings log")
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.mbSurface)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    disclaimer
                }
                .padding()
            }
            .background(Color.mbBackground.ignoresSafeArea())
            .navigationTitle("Health")
            .task {
                // Just-in-time HealthKit auth + one refresh on appear.
                await hk.requestAuthorization()
                await hk.refresh()
            }
            .refreshable {
                await hk.refresh()
            }
            .sheet(isPresented: $showingScanner) {
                HealthReadingScannerView(metricHint: scannerHint)
            }
        }
    }

    // MARK: - Subviews

    private var scanCTA: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Scan a device reading", systemImage: "camera.viewfinder")
                .font(.headline)
            Text("Snap a photo of a blood pressure monitor, glucometer, scale, or thermometer. We'll detect the values for you to confirm.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button {
                scannerHint = nil
                showingScanner = true
            } label: {
                Label("Scan Health Reading", systemImage: "camera.fill")
            }
            .buttonStyle(.mbPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mbCard()
    }

    private var healthKitGrid: some View {
        let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            metricTile("Steps", value: hk.snapshot.stepsToday.map { "\($0)" }, system: "figure.walk")
            metricTile("Active kcal", value: hk.snapshot.activeEnergyToday.map { String(format: "%.0f", $0) }, system: "flame.fill")
            metricTile("Heart rate", value: hk.snapshot.heartRate.map { "\(Int($0)) bpm" }, system: "heart.fill")
            metricTile("Resting HR", value: hk.snapshot.restingHeartRate.map { "\(Int($0)) bpm" }, system: "heart.text.square")
            metricTile("Sleep", value: hk.snapshot.sleepHoursLastNight.map { String(format: "%.1f h", $0) }, system: "bed.double.fill")
            metricTile("Weight", value: hk.snapshot.weightLatest.map { String(format: "%.1f kg", $0) }, system: "scalemass.fill")
            metricTile("SpO₂", value: hk.snapshot.spo2Latest.map { String(format: "%.0f%%", $0) }, system: "lungs.fill")
            metricTile("Glucose", value: hk.snapshot.glucoseLatest.map { String(format: "%.0f mg/dL", $0) }, system: "drop.fill")
            metricTile("Temp", value: hk.snapshot.bodyTempLatest.map { String(format: "%.1f °C", $0) }, system: "thermometer")
            if let sys = hk.snapshot.systolicLatest, let dia = hk.snapshot.diastolicLatest {
                metricTile("BP", value: "\(Int(sys)) / \(Int(dia))", system: "heart.text.square.fill")
            } else {
                metricTile("BP", value: nil, system: "heart.text.square.fill")
            }
        }
    }

    private func metricTile(_ title: String, value: String?, system: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: system)
                    .foregroundColor(.mbPrimary)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value ?? "—")
                .font(.title3.weight(.semibold))
                .foregroundColor(value == nil ? .secondary : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.mbSurface)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value ?? "no data")")
    }

    private var readingsList: some View {
        VStack(spacing: 8) {
            ForEach(readings.prefix(8)) { reading in
                HStack(spacing: 12) {
                    Image(systemName: reading.metric.systemImage)
                        .foregroundColor(.mbPrimary)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(reading.metric.rawValue)
                            .font(.subheadline.weight(.semibold))
                        Text(reading.date.mbDateTime())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(reading.displayValue)
                        .font(.headline)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.mbSurface)
                )
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var disclaimer: some View {
        Text("This information is for organization and tracking only and does not replace professional medical advice.")
            .font(.footnote)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }
}
