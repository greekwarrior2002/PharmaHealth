import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [CaregiverProfile]
    @StateObject private var subscription = SubscriptionManager.shared
    @StateObject private var notifications = NotificationManager.shared

    @AppStorage("defaultDoseReminderHour") private var defaultDoseReminderHour: Int = 8
    @AppStorage("defaultDoseReminderMinute") private var defaultDoseReminderMinute: Int = 0
    @AppStorage("refillLeadTimeDays") private var refillLeadTimeDays: Int = 5
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = true

    @State private var patientName: String = ""
    @State private var caregiverName: String = ""
    @State private var showingPaywall = false

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
