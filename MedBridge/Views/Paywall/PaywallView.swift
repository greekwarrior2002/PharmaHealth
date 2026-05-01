import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscription = SubscriptionManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    featureComparison
                    plans
                    Button("Restore Purchases") {
                        Task { await subscription.restorePurchases() }
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    Text("Cancel anytime in Settings. Subscription auto-renews until cancelled.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding()
            }
            .background(Color.mbBackground.ignoresSafeArea())
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .accessibilityLabel("Close")
                    }
                }
            }
            .alert(
                "Purchase error",
                isPresented: .constant(subscription.purchaseError != nil)
            ) {
                Button("OK") { subscription.purchaseError = nil }
            } message: {
                Text(subscription.purchaseError ?? "")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "star.fill")
                .font(.system(size: 44))
                .foregroundColor(.mbPrimary)
                .accessibilityHidden(true)
            Text("Unlock full MedBridge")
                .font(.largeTitle.weight(.bold))
            Text("Track unlimited medications and prepare better for every doctor visit.")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    private var featureComparison: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow(icon: "checkmark", title: "Free", subtitle: "Up to 2 medications, dose reminders", isPremium: false)
            featureRow(icon: "star.fill", title: "Premium", subtitle: "Unlimited medications, appointment prep summaries, PDF export, caregiver sharing", isPremium: true)
        }
        .mbCard()
    }

    private func featureRow(icon: String, title: String, subtitle: String, isPremium: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(isPremium ? .mbPrimary : .mbGood)
                .font(.title3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var plans: some View {
        VStack(spacing: 12) {
            planButton(
                title: "Annual",
                price: "$14.99/year",
                detail: "Save 37%",
                emphasized: true
            ) {
                Task { await subscription.purchaseAnnual() }
            }
            planButton(
                title: "Monthly",
                price: "$1.99/month",
                detail: nil,
                emphasized: false
            ) {
                Task { await subscription.purchaseMonthly() }
            }
        }
        .overlay(alignment: .center) {
            if subscription.isLoading {
                ProgressView().controlSize(.large)
            }
        }
    }

    private func planButton(
        title: String,
        price: String,
        detail: String?,
        emphasized: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(price)
                        .font(.subheadline)
                        .foregroundColor(emphasized ? .white.opacity(0.9) : .secondary)
                }
                Spacer()
                if let detail = detail {
                    Text(detail)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(emphasized ? Color.white.opacity(0.25) : Color.mbPrimary.opacity(0.15))
                        .foregroundColor(emphasized ? .white : .mbPrimary)
                        .cornerRadius(8)
                }
            }
            .padding(16)
            .frame(minHeight: 64)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(emphasized ? Color.mbPrimary : Color.mbSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(emphasized ? Color.clear : Color.mbPrimary, lineWidth: 1.5)
            )
            .foregroundColor(emphasized ? .white : .primary)
        }
        .buttonStyle(.plain)
        .disabled(subscription.isLoading)
        .accessibilityLabel("\(title) plan, \(price)\(detail.map { ", \($0)" } ?? "")")
    }
}
