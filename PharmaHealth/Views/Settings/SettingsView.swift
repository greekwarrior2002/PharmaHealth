import SwiftUI
import SwiftData
import UserNotifications
import CoreLocation

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [CaregiverProfile]
    @StateObject private var subscription = SubscriptionManager.shared
    @StateObject private var notifications = NotificationManager.shared
    @EnvironmentObject private var pharmacyPreferences: PharmacyPreferencesService

    @AppStorage("defaultDoseReminderHour") private var defaultDoseReminderHour: Int = 8
    @AppStorage("defaultDoseReminderMinute") private var defaultDoseReminderMinute: Int = 0
    @AppStorage("refillLeadTimeDays") private var refillLeadTimeDays: Int = 5
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = true
    @AppStorage("saveConfirmedReadingsToHealthKit") private var saveToHealth: Bool = false

    @StateObject private var healthKit = HealthKitService()

    @State private var patientName: String = ""
    @State private var caregiverName: String = ""
    @State private var showingPaywall = false
    @State private var showingPharmacyPicker = false

    private var profile: CaregiverProfile? {
        profiles.first
    }

    private var doseReminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: defaultDoseReminderHour,
                    minute: defaultDoseReminderMinute,
                    second: 0,
                    of: .now
                ) ?? .now
            },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                defaultDoseReminderHour = comps.hour ?? 8
                defaultDoseReminderMinute = comps.minute ?? 0
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Patient name", text: $patientName)
                        .onChange(of: patientName) { _, _ in saveProfile() }
                    if subscription.isPremium {
                        TextField("Caregiver name (optional)", text: $caregiverName)
                            .onChange(of: caregiverName) { _, _ in saveProfile() }
                    } else {
                        Button {
                            showingPaywall = true
                        } label: {
                            Label("Add caregiver (Premium)", systemImage: "lock.fill")
                        }
                    }
                }

                Section {
                    if let pharmacy = pharmacyPreferences.defaultPharmacy(in: context) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(pharmacy.name)
                                    .font(.body.weight(.semibold))
                                Text("Default")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.mbPrimary.opacity(0.15)))
                                    .foregroundColor(.mbPrimary)
                            }
                            if !pharmacy.address.isEmpty {
                                Text(pharmacy.address)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)

                        Button("Change default pharmacy") {
                            showingPharmacyPicker = true
                        }
                        Button(role: .destructive) {
                            pharmacyPreferences.clearDefault(in: context)
                        } label: {
                            Text("Remove default pharmacy")
                        }
                    } else {
                        Button {
                            showingPharmacyPicker = true
                        } label: {
                            Label("Choose default pharmacy", systemImage: "star")
                        }
                    }
                } header: {
                    Text("My Pharmacy")
                } footer: {
                    Text("Your default pharmacy is suggested when you add a new medication. You can change it for each medication.")
                        .font(.footnote)
                }

                Section("Reminders") {
                    DatePicker(
                        "Daily dose reminder",
                        selection: doseReminderTime,
                        displayedComponents: .hourAndMinute
                    )
                    Picker("Refill reminder lead time", selection: $refillLeadTimeDays) {
                        Text("5 days before").tag(5)
                        Text("7 days before").tag(7)
                        Text("10 days before").tag(10)
                    }
                }

                Section {
                    Toggle("Save confirmed readings to Apple Health", isOn: $saveToHealth)
                        .onChange(of: saveToHealth) { _, newValue in
                            if newValue {
                                Task { await healthKit.requestWriteAuthorization() }
                            }
                        }
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("When on, readings you tap Confirm are also written to Apple Health. PharmaHealth never writes unconfirmed values. You can revoke access any time in iOS Settings → Health → Data Access & Devices.")
                        .font(.footnote)
                }

                Section("Notifications") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(authStatusLabel)
                            .foregroundColor(.secondary)
                    }
                    if notifications.authorizationStatus == .denied {
                        Button("Open iOS Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                }

                Section("Subscription") {
                    HStack {
                        Text("Plan")
                        Spacer()
                        Text(subscription.isPremium ? "Premium" : "Free")
                            .foregroundColor(.secondary)
                    }
                    if !subscription.isPremium {
                        Button {
                            showingPaywall = true
                        } label: {
                            Label("Upgrade to Premium", systemImage: "star.fill")
                        }
                    } else if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        Link("Manage in App Store", destination: url)
                    }
                    Button("Restore Purchases") {
                        Task { await subscription.restorePurchases() }
                    }
                }

                Section("Onboarding") {
                    Button("Replay onboarding") {
                        hasCompletedOnboarding = false
                    }
                }

                Section("About") {
                    Link("Privacy policy", destination: URL(string: "https://example.com/privacy")!)
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showingPharmacyPicker) {
                PharmacyPickerView(
                    defaultPharmacy: nil
                ) { pick in
                    upsertAndSetDefault(pick)
                }
            }
            .task {
                await notifications.refreshAuthorizationStatus()
                if let profile = profile {
                    patientName = profile.patientName
                    caregiverName = profile.caregiverName ?? ""
                }
            }
        }
    }

    private var authStatusLabel: String {
        switch notifications.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return "Allowed"
        case .denied: return "Denied"
        case .notDetermined: return "Not requested"
        @unknown default: return "Unknown"
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    private func upsertAndSetDefault(_ pick: PharmacySearchResult) {
        let descriptor = FetchDescriptor<Pharmacy>()
        let pharmacy: Pharmacy
        if let existing = (try? context.fetch(descriptor))?.first(where: {
            $0.name == pick.name && $0.address == pick.address
        }) {
            if !pick.phone.isEmpty { existing.phone = pick.phone }
            pharmacy = existing
        } else {
            let newPharmacy = Pharmacy(
                name: pick.name,
                address: pick.address,
                phone: pick.phone,
                latitude: pick.coordinate?.latitude,
                longitude: pick.coordinate?.longitude
            )
            context.insert(newPharmacy)
            pharmacy = newPharmacy
        }
        pharmacyPreferences.setDefault(pharmacy, in: context)
    }

    private func saveProfile() {
        if let profile = profile {
            profile.patientName = patientName
            profile.caregiverName = caregiverName.isEmpty ? nil : caregiverName
        } else {
            let newProfile = CaregiverProfile(
                patientName: patientName,
                caregiverName: caregiverName.isEmpty ? nil : caregiverName
            )
            context.insert(newProfile)
        }
        try? context.save()
    }
}
