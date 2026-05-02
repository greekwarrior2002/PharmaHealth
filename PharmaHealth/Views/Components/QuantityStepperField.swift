import SwiftUI

/// Combined stepper + manual numeric entry. Useful for quantity / refill /
/// dose-amount fields where the user wants both quick +/- and direct typing.
struct QuantityStepperField: View {
    let title: String
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...10_000
    var step: Int = 1
    var unitLabel: String = ""

    @State private var text: String = ""
    @FocusState private var isEditing: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .layoutPriority(1)
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                Button {
                    decrement()
                } label: {
                    Image(systemName: "minus")
                        .font(.body.weight(.semibold))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .disabled(value <= range.lowerBound)
                .accessibilityLabel("Decrease \(title)")

                TextField("0", text: $text)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(minWidth: 56)
                    .focused($isEditing)
                    .onChange(of: text) { _, new in
                        // Strip non-digits and clamp.
                        let digits = new.filter { $0.isNumber }
                        if digits != new { text = digits }
                        if let n = Int(digits) {
                            value = min(max(n, range.lowerBound), range.upperBound)
                        } else if digits.isEmpty {
                            value = range.lowerBound
                        }
                    }
                    .onChange(of: value) { _, new in
                        if !isEditing { text = String(new) }
                    }
                    .onAppear { text = String(value) }

                Button {
                    increment()
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .disabled(value >= range.upperBound)
                .accessibilityLabel("Increase \(title)")
            }
            if !unitLabel.isEmpty {
                Text(unitLabel)
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(value) \(unitLabel)")
    }

    private func increment() {
        value = min(value + step, range.upperBound)
        MBHaptics.selection()
    }

    private func decrement() {
        value = max(value - step, range.lowerBound)
        MBHaptics.selection()
    }
}
