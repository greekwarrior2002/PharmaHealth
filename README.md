# PharmaHealth

Medication tracker with smart pharmacy reminders and doctor visit prep.

iOS 17+ · SwiftUI · SwiftData · MVVM · WidgetKit · RevenueCat

## What it does

- **Refill reminders** — Calculates when each medication will run out from quantity + dose frequency, then notifies you 5 days before so you can call any pharmacy yourself.
- **Appointment prep** — Generates a one-page summary of current medications, recent symptoms, and missed doses to share with your doctor.
- **Post-visit capture** — Quickly log new prescriptions and dose changes after a visit; the data feeds back into refill tracking.
- **Home Screen widget** — Glanceable status of the most urgent medication and next appointment.

## Project layout

```
PharmaHealth/
├── PharmaHealthApp.swift       App entry, SwiftData container, RevenueCat init
├── ContentView.swift           Tab bar host + onboarding gate
├── Models/                     SwiftData @Model classes
├── Services/                   RefillCalculator, NotificationManager,
│                               AppointmentPrepGenerator, SubscriptionManager
├── ViewModels/                 Dashboard / Medication / Appointment view models
├── Views/                      Dashboard, Medications, DoseLog, Symptoms,
│                               Appointments, Paywall, Settings, Onboarding
├── Utilities/                  PDFExporter, Color/View/Date extensions
├── Assets.xcassets             Color set assets (light + dark variants)
├── Info.plist
└── PharmaHealth.entitlements   App Group for shared SwiftData store

PharmaHealthWidget/
├── PharmaHealthWidget.swift    WidgetKit timeline provider + small/medium views
├── Assets.xcassets             Mirror of color set assets
├── Info.plist
└── PharmaHealthWidget.entitlements
```

## Opening the project

The repository ships with `PharmaHealth.xcodeproj` already generated. On a Mac:

```bash
git clone <this-repo>
cd PharmaHealth
git checkout claude/medbridge-ios-app-mgM6X
open PharmaHealth.xcodeproj
```

Xcode will fetch the RevenueCat Swift Package automatically the first time you build (this needs internet on first build only).

If you ever need to regenerate the project file (for example after adding new files outside Xcode), there's a Python script:

```bash
python3 scripts/generate_pbxproj.py
```

There's also a `project.yml` for [XcodeGen](https://github.com/yonaskolb/XcodeGen) that produces the same project, if you prefer that workflow.

## Required configuration

### 1. Bundle identifiers

Update both targets' bundle IDs from the placeholder `com.yourdomain.pharmahealth` (and `com.yourdomain.pharmahealth.widget`) to your own. Update them in:

- `project.yml` — `PRODUCT_BUNDLE_IDENTIFIER` for both targets
- `PharmaHealth/PharmaHealthApp.swift` — `appGroupIdentifier` static
- `PharmaHealthWidget/PharmaHealthWidget.swift` — `appGroupIdentifier` constant
- `PharmaHealth/PharmaHealth.entitlements` — `com.apple.security.application-groups`
- `PharmaHealthWidget/PharmaHealthWidget.entitlements` — `com.apple.security.application-groups`

### 2. App Group

Create an App Group named `group.<your-bundle-id>.pharmahealth` in the Apple Developer Portal and enable it on both targets in *Signing & Capabilities*. The shared SwiftData store lives in this container so the widget can read it.

### 3. RevenueCat API key

Replace the placeholder in `PharmaHealth/Services/SubscriptionManager.swift`:

```swift
static let revenueCatAPIKey = "YOUR_REVENUECAT_API_KEY"
```

The two product identifiers used are `pharmahealth_monthly_199` and `pharmahealth_annual_1499`. These need to match products configured in App Store Connect and linked to the `premium` entitlement in your RevenueCat dashboard.

**Never hardcode third-party API keys (Anthropic, OpenAI, etc.) inside an iOS app** — anyone who installs the app can extract them from the binary. If you add an AI feature later, route the call through a backend service that holds the key.

### 4. Notifications & background modes

Notifications are requested at the end of onboarding. No background modes capability is required because reminders are local-only via `UNCalendarNotificationTrigger`.

## Running on a device

1. In Xcode, select the `PharmaHealth` scheme and a connected device.
2. *Signing & Capabilities*: choose your team for both `PharmaHealth` and `PharmaHealthWidget`. Add the App Group capability and select the group from step 2 above.
3. Build and run (⌘R).
4. Add the **PharmaHealth** widget on your Home Screen via the widget gallery.

## Free vs Premium

| Feature                       | Free            | Premium |
|-------------------------------|-----------------|---------|
| Active medications            | up to 2         | Unlimited |
| Dose reminders                | ✅              | ✅ |
| Appointment prep summary      | —               | ✅ |
| PDF export of prep summary    | —               | ✅ |
| Caregiver profile             | —               | ✅ |

## Out of scope

This v1 deliberately does not include: pharmacy API integrations, vitals tracking, drug-interaction checks, clinical decision support, family chat, or multi-device sync. The app is a personal tracker, not a clinical tool.
