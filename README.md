# Health Export

A SwiftUI iOS app that reads a focused set of Apple Health (HealthKit) samples and exports them as **CSV** or **JSON** via the system Share sheet.

The app is **read-only**. It does not write to HealthKit, does not use Clinical Health Records, and does not upload data. Files leave the device only if you share them.

This is an **iPhone-only** app (`TARGETED_DEVICE_FAMILY = 1`, Mac Catalyst off). A MacBook is the machine you use to build and install. Real Apple Health data is only available on a **physical iPhone (iOS 17+)**.

## 你只需要做（一定要你個 Apple ID / iPhone）

Repo 入面嘅 app、HealthKit entitlement、usage description、automatic signing、scheme 已經搞好。呢邊係 Linux 雲端機，**入唔到你部 Mac，亦登唔入你個 Apple Account**，所以淨係下面幾樣要你做：

1. **Mac App Store** 用你個 Apple ID 裝 **Xcode 16**（或 15.4+），開一次等 extra components 裝完。
2. **Xcode → Settings → Accounts → +** 登入同一個 Apple ID（免費 Personal Team 得）。
3. 雙擊 `HealthExport.xcodeproj`（或 `Open Health Export.command`）→ target **HealthExport** → **Signing & Capabilities** → **Team** 揀你個帳號。唔好開 Clinical Health Records。Bundle ID 如果報被佔用，先改。
4. USB 插 **實體 iPhone**（唔好揀 Simulator）→ 開 **設定 → 私隱與安全性 → 開發者模式** → Xcode 撳 Run。iPhone 叫 Trust / Untrusted Developer 就 Trust。
5. App 入面 **Continue with Apple Health**，打開 Steps、Heart Rate、Active Energy、Sleep、Workouts，然後 Load preview → Share CSV / JSON。

之後改 Health 權限：**健康 → 頭像 → 私隱 → App → Health Export**。

## 已經幫你做好

- SwiftUI app 同 HealthKit 讀取 / CSV+JSON export
- [`HealthExport/HealthExport.entitlements`](HealthExport/HealthExport.entitlements)：HealthKit on、clinical records off
- Info.plist usage strings、automatic signing（`CODE_SIGN_STYLE = Automatic`，identity `Apple Development`）
- Shared **HealthExport** scheme

```mermaid
flowchart LR
  you[You: Apple ID and iPhone]
  xcode[Xcode Team plus Run]
  health[Allow Health types]
  export[Share CSV JSON]
  you --> xcode --> health --> export
```

### 唔好揀嘅 destination

- **iPhone Simulator**：`HKHealthStore.isHealthDataAvailable()` 係 false，會見到「Apple Health unavailable」。只適合跑 unit test（`Product → Test`）
- **My Mac / Mac Catalyst**：工程已關閉，而且 Mac 冇 iPhone 個 Health 資料庫

### 常見錯誤

| 情況 | 點算 |
| --- | --- |
| Failed to register bundle identifier | 改 bundle ID 成你自己嘅 |
| Signing for HealthKit requires a development team | Accounts 未登入，或者 Team 未揀 |
| Developer Mode disabled | **設定 → 私隱與安全性 → 開發者模式** |
| Preview 全部 0 樣本 | 可能冇數據，或者 Health 入面未授權該類型（HealthKit **唔會**話你 denied） |

---

## Requirements

- A Mac with **Xcode 15.4+** (Xcode 16 recommended)
- An Apple ID in Xcode (**Xcode → Settings → Accounts**). A free Personal Team is enough to install on your own iPhone
- A **physical iPhone** running iOS 17 or later

HealthKit is not available in the iOS Simulator. `HKHealthStore.isHealthDataAvailable()` is false there, and the app shows an empty state instead of querying data.

## Open in Xcode

1. Clone this repository (see the commands above).
2. Open `HealthExport.xcodeproj` (double-click it, run `Open Health Export.command`, or `open HealthExport.xcodeproj`).
3. Select the **HealthExport** scheme and an attached **physical iPhone**.

## Signing

1. Select the **HealthExport** project in the navigator, then the **HealthExport** target.
2. Open **Signing & Capabilities**.
3. Choose your **Team**.
4. Confirm the bundle identifier `com.arlun2005.HealthExport` is unique to you (change it if Xcode reports a conflict).
5. Confirm the **HealthKit** capability is present. The entitlement file is `HealthExport/HealthExport.entitlements` and does **not** include Clinical Health Records (`com.apple.developer.healthkit.access` is an empty array).

Automatic signing is enabled. Xcode will create an App ID with HealthKit when you first run on a device.

## Run on a physical iPhone

1. Unlock the phone, connect it with USB (or use wireless debugging), and trust the computer if asked.
2. On the phone: **Settings → Privacy & Security → Developer Mode** (iOS 16+) and enable it if needed, then restart.
3. In Xcode, pick your iPhone as the run destination (not Simulator) and press Run (⌘R).
4. If iOS blocks the developer app: **Settings → General → VPN & Device Management** and trust your developer certificate.
5. After launch, tap **Continue with Apple Health** and enable Steps, Heart Rate, Active Energy, Sleep, and Workouts.

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

On a Mac, with the HealthExport scheme selected:

```bash
xcodebuild -scheme HealthExport -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Use whatever iPhone simulator name your Xcode provides. Unit tests cover CSV escaping, JSON metadata, file writing, and date-range bounds. They do not require a physical device or HealthKit permission.

## Project layout

```
HealthExport.xcodeproj      Xcode project (shared scheme included)
Open Health Export.command  Double-click on a Mac to open the project
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
