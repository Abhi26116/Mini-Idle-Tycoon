# Mini-Idle-Tycoon
Mini Idle Tycoon game

A SwiftUI idle tycoon (theme: Startup Studio) built with MVVM and Swift Concurrency. Targets iOS 17+.

## Project structure

```
MiniIdleTycoon/
├── MiniIdleTycoonApp.swift        # @main entry, ScenePhase → save / offline earnings
├── Assets.xcassets/               # App icon
├── Info.plist                     # Ad IDs, ATT text, SKAdNetwork (merged with the generated plist)
├── PrivacyInfo.xcprivacy          # Privacy manifest for the app's own code
├── Models/
│   ├── Station.swift              # Station data + starting lineup
│   ├── PlayerProfile.swift        # Coins, gems, investors & lifetime earnings
│   └── OfflineEarnings.swift      # "Welcome back" sheet data
├── Services/
│   ├── SaveManager.swift          # UserDefaults persistence
│   ├── AdsManager.swift           # Rewarded-ad protocol (+ async bridge)
│   ├── GoogleAdsManager.swift     # AdMob rewarded ads + UMP consent + ATT
│   └── MockAdsManager.swift       # Fake ad for tests and previews
├── Utilities/
│   ├── GameMath.swift             # Cost, bulk-buy, milestone, investor, offline formulas
│   ├── Haptics.swift              # UIImpactFeedbackGenerator wrapper
│   └── NumberFormatting.swift     # 12350 → "12.35K"
├── ViewModels/
│   ├── BuyMode.swift              # ×1 / ×10 / ×100 / Max upgrade amount
│   ├── GameEngineViewModel.swift  # Game loop, purchases, prestige, offline earnings
│   └── StationRowState.swift      # Precomputed per-row display state
└── Views/
    ├── MainGameView.swift         # Currency header + station list
    ├── StationRowView.swift       # One station card
    ├── OfflineEarningsView.swift  # Offline earnings sheet
    ├── PrestigeView.swift         # "Sell your studio" investors sheet
    └── ProfitBoostView.swift      # "2X Profit Boost Active" banner / ad button

MiniIdleTycoonTests/               # XCTest unit tests (math, models, engine, saves)
Scripts/generate_app_icon.swift    # Redraws the app icon PNG
```

## Progression

- **Milestones:** a station's revenue doubles at levels 10, 25, 50, 100, 150,
  200, 300, 400 and 500 (`GameMath.milestoneLevels`).
- **Bulk buy:** the ×1 / ×10 / ×100 / Max picker sets how many levels one
  Upgrade tap buys. Fixed amounts are all-or-nothing; Max buys what you can afford.
- **Investors (prestige):** lifetime earnings attract investors
  (`√(lifetime coins / 1M)` in total). Selling the studio claims them and
  restarts the stations and coins; each investor adds +2% to all profit forever.
  Investors, lifetime earnings, gems and an active boost carry over.

## Running on your iPhone

Requires Xcode 15 or later. To run on a device, your Xcode must also support
the iPhone's iOS version.

1. Open `MiniIdleTycoon.xcodeproj`.
2. Select the **MiniIdleTycoon** target → **Signing & Capabilities** → pick your
   Apple ID under **Team** (add it first in Xcode → Settings → Accounts).
3. Plug in your iPhone, pick it in the device menu at the top, press **⌘R**.

First time on a device: enable **Settings → Privacy & Security → Developer Mode**
on the iPhone, and after installing, trust your profile under
**Settings → General → VPN & Device Management**.

The project lists its source files explicitly (so it opens in Xcode 15), so add
new files through Xcode's File → New → File… to include them in the target. Every push is also built and tested on a macOS runner by
`.github/workflows/ios-build.yml`.

## Running the tests

In Xcode press **⌘U**. From the command line:

```bash
xcodebuild test -project MiniIdleTycoon.xcodeproj -scheme MiniIdleTycoon -destination 'platform=iOS Simulator,name=<your simulator>'
```

New test files go in `MiniIdleTycoonTests/`; add them to the **MiniIdleTycoonTests**
target via File → New → File… so the project picks them up.

## App icon

The icon is drawn in code so it can be tweaked and regenerated:

```bash
swift Scripts/generate_app_icon.swift
```

This overwrites `MiniIdleTycoon/Assets.xcassets/AppIcon.appiconset/AppIcon.png`
(1024×1024, opaque; Xcode makes the smaller sizes). To use your own artwork
instead, drop a 1024×1024 PNG without transparency in its place.

## Ads (Google AdMob)

Rewarded ads use the Google Mobile Ads SDK (Swift Package, pinned to 13.10.0).
On launch `GoogleAdsManager` runs Google's required order: consent form (UMP,
only where the law requires it) → App Tracking Transparency prompt → SDK start →
preload an ad. The boost is granted only when the player earns the reward and
closes the ad. Unit tests use `MockAdsManager` and never start the SDK.

**Before release**, replace Google's public test IDs with your own from the
AdMob console (Apps → your app → App settings, and Ad units → your rewarded unit).
They are build settings on the **MiniIdleTycoon** target (Build Settings →
User-Defined), so Debug can keep the test IDs:

| Setting | Test value (current) |
| --- | --- |
| `GAD_APPLICATION_ID` | `ca-app-pub-3940256099942544~1458002511` |
| `REWARDED_AD_UNIT_ID` | `ca-app-pub-3940256099942544/1712485313` |

Never tap your own live ads; use test IDs or register your iPhone as a test
device in AdMob. Also in the AdMob console, set up the **Privacy & messaging**
GDPR and IDFA messages. `Info.plist` lists Google's
[SKAdNetwork IDs](https://developers.google.com/admob/ios/3p-skadnetworks);
refresh them from that page now and then.

To use a different ad network, write a class that conforms to `AdsManager`
(call `completion(true)` only when the reward is earned, and exactly once) and
create it in `MiniIdleTycoonApp.init()` instead of `GoogleAdsManager`.

## Build phases

1. Models & math ✅
2. Game engine loop ✅
3. Offline earnings & persistence ✅
4. SwiftUI front end ✅
5. Monetization wrappers ✅ (Google AdMob rewarded ads, UMP consent, ATT)
6. Progression: milestones, bulk buy, prestige ✅
