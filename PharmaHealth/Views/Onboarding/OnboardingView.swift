import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    @State private var page: Int = 0
    @State private var patientName: String = ""
    @State private var isCaregiver: Bool = false

    var body: some View {
        VStack {
            TabView(selection: $page) {
                page1.tag(0)
                page2.tag(1)
                page3.tag(2)
                page4.tag(3)
                page5.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            HStack {
                if page > 0 {
                    Button("Back") { page -= 1 }
                        .frame(minHeight: 52)
                        .frame(maxWidth: .infinity)
                }
                if page < 4 {
                    Button {
                        page += 1
                    } label: {
                        Text("Continue")
                    }
                    .mbPrimaryButton()
                    .disabled(page == 3 && patientName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding()
        }
        .background(Color.mbBackground.ignoresSafeArea())
    }

    private var page1: some View {
        onboardingPage(
            icon: "pills.fill",
            title: "Welcome to PharmaHealth",
            description: "A simple way to keep track of your medications and stay on top of pharmacy refills."
        )
    }

    private var page2: some View {
        onboardingPage(
            icon: "calendar.badge.clock",
            title: "Track your medications",
            description: "Tell us how many pills you have. We'll calculate when you'll run out and remind you to call the pharmacy 5 days before."
        )
    }

    private var page3: some View {
        onboardingPage(
            icon: "doc.text",
            title: "Prepare for appointments",
            description: "Generate a one-page summary of your medications, recent symptoms, and missed doses to share with your doctor."
        )
    }

    private var page4: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 80))
                .foregroundColor(.mbPrimary)
                .accessibilityHidden(true)
            Text("Who is this for?")
                .font(.largeTitle.weight(.bold))
            Text("Tell us your name (or the name of the person you're helping).")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            TextField("Your name", text: $patientName)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
                .padding(.horizontal)

            HStack(spacing: 12) {
                Button {
                    isCaregiver = false
                } label: {
                    Text("For myself")
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isCaregiver ? Color.clear : Color.mbPrimary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.mbPrimary, lineWidth: 1.5)
                        )
                        .foregroundColor(isCaregiver ? .mbPrimary : .white)
                }
                Button {
                    isCaregiver = true
                } label: {
                    Text("I'm a caregiver")
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isCaregiver ? Color.mbPrimary : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.mbPrimary, lineWidth: 1.5)
                        )
                        .foregroundColor(isCaregiver ? .white : .mbPrimary)
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }

    private var page5: some View {
        VStack(spacing: 24) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 80))
                .foregroundColor(.mbPrimary)
                .accessibilityHidden(true)
            Text("Allow notifications")
                .font(.largeTitle.weight(.bold))
            Text("We'll remind you to call the pharmacy before you run out, and the day before each appointment.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                Task {
                    _ = await NotificationManager.shared.requestAuthorization()
                    finish()
                }
            } label: {
                Text("Allow notifications")
            }
            .mbPrimaryButton()
            .padding(.horizontal)

            Button("Maybe later") {
                finish()
            }
            .frame(minHeight: 52)
        }
        .padding()
    }

    private func onboardingPage(icon: String, title: String, description: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: icon)
                .font(.system(size: 100))
                .foregroundColor(.mbPrimary)
                .accessibilityHidden(true)
            Text(title)
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            Text(description)
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
        .padding()
    }

    private func finish() {
        let trimmed = patientName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            let profile = CaregiverProfile(patientName: trimmed)
            context.insert(profile)
            try? context.save()
        }
        hasCompletedOnboarding = true
    }
}
