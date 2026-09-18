# Health Export

A SwiftUI iOS app that reads a focused set of Apple Health (HealthKit) samples and exports them as **CSV** or **JSON** via the system Share sheet.

The app is **read-only**. It does not write to HealthKit, does not use Clinical Health Records, and does not upload data. Files leave the device only if you share them.

## Requirements

- A Mac with **Xcode 15.4+** (Xcode 16 recommended)
- An Apple Developer account (free or paid) for device signing
- A **physical iPhone** running iOS 17 or later

HealthKit is not available in the iOS Simulator. `HKHealthStore.isHealthDataAvailable()` is false there, and the app shows an empty state instead of querying data.

## Open in Xcode

1. Clone this repository.
2. Open `HealthExport.xcodeproj` (double-click it or `open HealthExport.xcodeproj` from Terminal).
3. Select the **Health Export** scheme and an attached iPhone.

## Signing

1. Select the **HealthExport** project in the navigator, then the **Health Export** target.
2. Open **Signing & Capabilities**.
3. Choose your **Team**.
4. Confirm the bundle identifier `com.arlun2005.HealthExport` is unique to you (change it if Xcode reports a conflict).
5. Confirm the **HealthKit** capability is present. The entitlement file is `HealthExport/HealthExport.entitlements` and does **not** include Clinical Health Records (`com.apple.developer.healthkit.access` is an empty array).

Automatic signing is enabled. Xcode will create an App ID with HealthKit when you first run on a device.

## Run on a physical iPhone

1. Unlock the phone, connect it with USB (or use wireless debugging), and trust the computer if asked.
2. On the phone: **Settings → Privacy & Security → Developer Mode** (iOS 16+) and enable it if needed.
3. In Xcode, pick your iPhone as the run destination and press Run.
4. If iOS blocks the developer app: **Settings → General → VPN & Device Management** and trust your developer certificate.
5. After launch, tap **Continue with Apple Health** and enable the types you want this app to read.

To change access later: **Health → Profile (your picture) → Privacy → Apps → Health Export**.

## What v1 exports

| Type | HealthKit identifier | Export notes |
| --- | --- | --- |
| Steps | `stepCount` | Raw quantity samples, unit `count` |
| Heart rate | `heartRate` | Raw samples, unit `count/min` |
| Active energy | `activeEnergyBurned` | Raw samples, unit `kcal` |
| Sleep analysis | `sleepAnalysis` | Category samples; `detail` is the stage (`inBed`, `asleepCore`, `asleepREM`, …) |
| Workouts | `HKWorkoutType` | Activity name, duration, energy (kcal), distance (meters) |

Each row also includes UTC ISO-8601 start/end, source, device, and sample UUID.

Date ranges are local calendar days. The selected end date is included through the end of that day.

Queries cap each type at **50,000 samples** so long heart-rate ranges stay memory-safe. If a type is capped, the preview warns you.

## Usage in the app

1. **Authorize** — the first screen explains exactly which types are requested and why.
2. **Select range and types** — presets (7 / 30 / 90 days, year to date) or a custom range.
3. **Preview summary** — counts and simple totals. Empty results are expected both when there is no data **and** when read access was denied (HealthKit does not reveal read permission).
4. **Export** — Share CSV and/or JSON to Files, AirDrop, or another app.

## Privacy strings

`NSHealthShareUsageDescription` states that samples are read only to build an on-device CSV/JSON export.

`NSHealthUpdateUsageDescription` is included because HealthKit can require it when the store is initialized. The string is explicit that **this app does not write** to Apple Health.

## Tests

On a Mac, with the Health Export scheme selected:

```bash
xcodebuild -scheme HealthExport -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Unit tests cover CSV escaping, JSON metadata, file writing, and date-range bounds. They do not require a physical device or HealthKit permission.

## Project layout

```
HealthExport.xcodeproj      Xcode project (shared scheme included)
HealthExport/
  App/                      SwiftUI entry + session
  Models/                   Types, date range, export records
  Services/                 HealthKit queries + CSV/JSON builders
  Views/                    Authorize → setup → preview
  HealthExport.entitlements HealthKit (no clinical records)
  Info.plist                Health usage descriptions
HealthExportTests/          Formatter and date-range tests
```

## Next steps

- Add more quantity types (resting heart rate, walking/running distance, body mass, VO2 max).
- Optional daily aggregation instead of (or in addition to) raw samples.
- Paginated queries above the 50,000-sample cap, or streamed writes for very large exports.
- Workout route / GPX export.
- Additional formats (TSV, Apple Health XML-compatible).
- Localizations and iPad layout polish.

Do not add Clinical Health Records unless you complete Apple’s extra review and entitlement process.
