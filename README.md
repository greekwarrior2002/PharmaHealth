# MedBridge

Medication tracker with smart pharmacy reminders and doctor visit prep.

iOS 17+ · SwiftUI · SwiftData · MVVM · WidgetKit · RevenueCat

## What it does

- **Refill reminders** — Calculates when each medication will run out from quantity + dose frequency, then notifies you 5 days before so you can call any pharmacy yourself.
- **Appointment prep** — Generates a one-page summary of current medications, recent symptoms, and missed doses to share with your doctor.
- **Post-visit capture** — Quickly log new prescriptions and dose changes after a visit; the data feeds back into refill tracking.
- **Home Screen widget** — Glanceable status of the most urgent medication and next appointment.

## Project layout

```
MedBridge/
├── MedBridgeApp.swift          App entry, SwiftData container, RevenueCat init
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
└── MedBridge.entitlements      App Group for shared SwiftData store

MedBridgeWidget/
├── MedBridgeWidget.swift       WidgetKit timeline provider + small/medium views
├── Assets.xcassets             Mirror of color set assets
├── Info.plist
└── MedBridgeWidget.entitlements
```

## Generating the Xcode project

The repository ships with a `project.yml` for [XcodeGen](https://github.com/yonaskolb/XcodeGen). The generated `.xcodeproj` is git-ignored.

```bash
brew install xcodegen
xcodegen generate
open MedBridge.xcodeproj
```

XcodeGen is the recommended path because it keeps the project structure declarative and makes setup reproducible. If you'd rather build the project in Xcode directly, create a new SwiftUI app target named `MedBridge` and a Widget Extension named `MedBridgeWidget`, then drag in the `MedBridge/` and `MedBridgeWidget/` source folders, the assets, plists, and entitlements files. Add the RevenueCat Swift Package (see below) to the `MedBridge` target. Add the shared files (`Models/`, `Services/RefillCalculator.swift`, `Utilities/Extensions.swift`) to both targets so the widget can read the same data.

## Required configuration

### 1. Bundle identifiers

Update both targets' bundle IDs from the placeholder `com.yourdomain.medbridge` (and `com.yourdomain.medbridge.widget`) to your own. Update them in:

- `project.yml` — `PRODUCT_BUNDLE_IDENTIFIER` for both targets
- `MedBridge/MedBridgeApp.swift` — `appGroupIdentifier` static
- `MedBridgeWidget/MedBridgeWidget.swift` — `appGroupIdentifier` constant
- `MedBridge/MedBridge.entitlements` — `com.apple.security.application-groups`
- `MedBridgeWidget/MedBridgeWidget.entitlements` — `com.apple.security.application-groups`

### 2. App Group

Create an App Group named `group.<your-bundle-id>.medbridge` in the Apple Developer Portal and enable it on both targets in *Signing & Capabilities*. The shared SwiftData store lives in this container so the widget can read it.

### 3. RevenueCat API key

Replace the placeholder in `MedBridge/Services/SubscriptionManager.swift`:

```swift
static let revenueCatAPIKey = "YOUR_REVENUECAT_API_KEY"
```

The two product identifiers used are `medbridge_monthly_199` and `medbridge_annual_1499`. These need to match products configured in App Store Connect and linked to the `premium` entitlement in your RevenueCat dashboard.

### 4. Notifications & background modes

Notifications are requested at the end of onboarding. No background modes capability is required because reminders are local-only via `UNCalendarNotificationTrigger`.

## Running on a device

1. In Xcode, select the `MedBridge` scheme and a connected device.
2. *Signing & Capabilities*: choose your team for both `MedBridge` and `MedBridgeWidget`. Add the App Group capability and select the group from step 2 above.
3. Build and run (⌘R).
4. Add the **MedBridge** widget on your Home Screen via the widget gallery.

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
