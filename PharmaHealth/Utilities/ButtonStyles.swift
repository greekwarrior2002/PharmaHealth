import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Reusable button styles that guarantee the entire visible button area is
// hit-testable (via `.contentShape(...)`) and provide consistent sizing,
// haptics, and pressed-state feedback across the app.

/// Filled primary action button (white text on tinted background).
struct MBPrimaryButtonStyle: ButtonStyle {
    var tint: Color = .mbPrimary
    var minHeight: CGFloat = 52
    var cornerRadius: CGFloat = 12

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            // Make the entire visible rectangle tappable, not just the text.
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Outlined secondary button (tint colored text + border).
struct MBSecondaryButtonStyle: ButtonStyle {
    var tint: Color = .mbPrimary
    var minHeight: CGFloat = 52
    var cornerRadius: CGFloat = 12

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(tint)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(tint, lineWidth: 1.5)
            )
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Subtle tinted "tag/chip" button used in selection grids.
struct MBChipButtonStyle: ButtonStyle {
    var isSelected: Bool
    var tint: Color = .mbPrimary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity)
            .foregroundColor(isSelected ? .white : tint)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? tint : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(tint, lineWidth: 1.5)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == MBPrimaryButtonStyle {
    static var mbPrimary: MBPrimaryButtonStyle { .init() }
}

extension ButtonStyle where Self == MBSecondaryButtonStyle {
    static var mbSecondary: MBSecondaryButtonStyle { .init() }
}

// MARK: - Lightweight haptics helper

enum MBHaptics {
    static func selection() {
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    static func warning() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }
}
