import Foundation
import RevenueCat

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // TODO: Replace with the RevenueCat API key from your dashboard.
    static let revenueCatAPIKey = "YOUR_REVENUECAT_API_KEY"

    static let entitlementID = "premium"
    static let monthlyProductID = "medbridge_monthly_199"
    static let annualProductID = "medbridge_annual_1499"

    static let freeMedicationLimit = 2

    @Published var isPremium: Bool = false
    @Published var offerings: Offerings?
    @Published var isLoading: Bool = false
    @Published var purchaseError: String?

    private init() {}

    static func configure() {
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: revenueCatAPIKey)
    }

    func refresh() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            self.isPremium = info.entitlements[Self.entitlementID]?.isActive == true
            self.offerings = try await Purchases.shared.offerings()
        } catch {
            self.purchaseError = error.localizedDescription
        }
    }

    func purchaseMonthly() async {
        await purchase(productID: Self.monthlyProductID)
    }

    func purchaseAnnual() async {
        await purchase(productID: Self.annualProductID)
    }

    private func purchase(productID: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let products = await Purchases.shared.products([productID])
            guard let product = products.first else {
                self.purchaseError = "Product not available."
                return
            }
            let result = try await Purchases.shared.purchase(product: product)
            self.isPremium = result.customerInfo.entitlements[Self.entitlementID]?.isActive == true
        } catch {
            self.purchaseError = error.localizedDescription
        }
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            self.isPremium = info.entitlements[Self.entitlementID]?.isActive == true
        } catch {
            self.purchaseError = error.localizedDescription
        }
    }

    // MARK: - Gating helpers

    func canAddMoreMedications(currentActiveCount: Int) -> Bool {
        isPremium || currentActiveCount < Self.freeMedicationLimit
    }

    var canGeneratePrepSummary: Bool { isPremium }
    var canExportPDF: Bool { isPremium }
    var canUseCaregiverProfile: Bool { isPremium }
}
