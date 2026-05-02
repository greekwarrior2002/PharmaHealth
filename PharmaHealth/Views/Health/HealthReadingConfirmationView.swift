import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Mandatory user-confirmation step after OCR. The user can edit the metric
/// type, the value, the unit, and the date, optionally add a note, and only
/// then save. We never persist OCR output silently.
struct HealthReadingConfirmationView: View {
    @Environment(\.dismiss) private var dismiss

    let image: UIImage
    let candidates: [ParsedHealthReading]
    let metricHint: HealthMetricType?
    let onSave: (HealthReading) -> Void
    let onRetake: () -> Void

    @State private var metric: HealthMetricType
    @State private var primaryText: String
    @State private var secondaryText: String
    @State private var unit: String
    @State private var date: Date = .now
    @State private var note: String = ""
    @State private var validation: HealthReadingValidator.ValidationResult = .ok
    @State private var didDetectAny: Bool

    init(
        image: UIImage,
        candidates: [ParsedHealthReading],
        metricHint: HealthMetricType?,
        onSave: @escaping (HealthReading) -> Void,
        onRetake: @escaping () -> Void
    ) {
        self.image = image
        self.candidates = candidates
        self.metricHint = metricHint
        self.onSave = onSave
        self.onRetake = onRetake

        // Pick the best candidate, falling back to the metric hint or
        // heart rate as a sensible default. Wrapped in `_State` so the
        // initializer compiles inside a SwiftUI View.
        let chosen = candidates.first ?? candidates.first(where: { $0.metric == metricHint })
        let initialMetric = chosen?.metric ?? metricHint ?? .heartRate
        _metric = State(initialValue: initialMetric)
        _primaryText = State(initialValue: chosen.map { Self.format($0.primary) } ?? "")
        _secondaryText = State(initialValue: chosen?.secondary.map { Self.format($0) } ?? "")
        _unit = State(initialValue: chosen?.unit ?? initialMetric.defaultUnit)
        _didDetectAny = State(initialValue: !candidates.isEmpty)
    }

    private static func format(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 180)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Section {
                    Label(
                        didDetectAny ? "Detected — please confirm" : "Nothing detected — please enter manually",
                        systemImage: didDetectAny ? "wand.and.stars" : "exclamationmark.bubble"
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }

                Section("Reading") {
                    Picker("Metric", selection: $metric) {
                        ForEach(HealthMetricType.allCases) { m in
                            Label(m.rawValue, systemImage: m.systemImage).tag(m)
                        }
                    }
                    .onChange(of: metric) { _, new in
                        // Update unit suggestion if it doesn't match the new metric.
                        if !knownUnits(for: new).contains(unit) {
                            unit = new.defaultUnit
                        }
                        revalidate()
                    }

                    HStack {
                        Text(primaryFieldLabel)
                        Spacer()
                        TextField("0", text: $primaryText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: primaryText) { _, _ in revalidate() }
                            .frame(maxWidth: 120)
                    }

                    if metric == .bloodPressure {
                        HStack {
                            Text("Diastolic")
                            Spacer()
                            TextField("0", text: $secondaryText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .onChange(of: secondaryText) { _, _ in revalidate() }
                                .frame(maxWidth: 120)
                        }
                    }

                    HStack {
                        Text("Unit")
                        Spacer()
                        Picker("Unit", selection: $unit) {
                            ForEach(knownUnits(for: metric), id: \.self) { u in
                                Text(u).tag(u)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }

                Section("When") {
                    DatePicker("Date", selection: $date, in: ...Date())
                }

                Section("Note (optional)") {
                    TextField("Add context (e.g. after meal)", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }

                if case let .suspicious(message) = validation {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.mbUrgent)
                            .font(.subheadline)
                        Text("This value may be outside a typical range. Consider checking it again or contacting a healthcare professional if concerned.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                if case let .impossible(message) = validation {
                    Section {
                        Label(message, systemImage: "xmark.octagon.fill")
                            .foregroundColor(.mbDanger)
                            .font(.subheadline)
                    }
                }

                Section {
                    Button {
                        onRetake()
                        dismiss()
                    } label: {
                        Label("Retake Photo", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.mbSecondary)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
            }
            .navigationTitle("Confirm Reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Confirm") { saveIfValid() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onAppear { revalidate() }
        }
    }

    // MARK: - Helpers

    private var primaryFieldLabel: String {
        switch metric {
        case .bloodPressure: return "Systolic"
        case .bloodOxygen:   return "SpO₂"
        case .heartRate:     return "Pulse"
        case .weight:        return "Weight"
        case .temperature:   return "Temperature"
        case .bloodGlucose:  return "Glucose"
        }
    }

    private func knownUnits(for metric: HealthMetricType) -> [String] {
        switch metric {
        case .bloodPressure: return ["mmHg"]
        case .bloodOxygen:   return ["%"]
        case .heartRate:     return ["bpm"]
        case .weight:        return ["kg", "lb"]
        case .temperature:   return ["°C", "°F"]
        case .bloodGlucose:  return ["mg/dL", "mmol/L"]
        }
    }

    private var canSave: Bool {
        guard let primary = Double(primaryText) else { return false }
        if metric == .bloodPressure, Double(secondaryText) == nil { return false }
        if case .impossible = validation { return false }
        return primary > 0
    }

    private func revalidate() {
        guard let primary = Double(primaryText) else {
            validation = .ok
            return
        }
        let secondary = Double(secondaryText)
        validation = HealthReadingValidator.validate(
            metric: metric,
            primary: primary,
            secondary: secondary,
            unit: unit
        )
    }

    private func saveIfValid() {
        guard let primary = Double(primaryText) else { return }
        let secondary = Double(secondaryText)
        let isValidated: Bool
        switch validation {
        case .ok:           isValidated = true
        case .suspicious:   isValidated = true   // user explicitly confirmed
        case .impossible:   return               // hard-block
        }
        let reading = HealthReading(
            metric: metric,
            primaryValue: primary,
            secondaryValue: metric == .bloodPressure ? secondary : nil,
            unit: unit,
            date: date,
            source: .cameraScan,
            note: note,
            isValidated: isValidated
        )
        onSave(reading)
        dismiss()
    }
}
