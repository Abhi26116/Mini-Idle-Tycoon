# Mini-Idle-Tycoon
Mini Idle Tycoon game

A SwiftUI idle tycoon (theme: Startup Studio) built with MVVM and Swift Concurrency. Targets iOS 17+.

## Project structure

```
MiniIdleTycoon/
├── MiniIdleTycoonApp.swift        # @main entry, ScenePhase → save / offline earnings
├── Models/
│   ├── Station.swift              # Station data + starting lineup
│   ├── PlayerProfile.swift        # Coins, gems, investors & lifetime earnings
│   └── OfflineEarnings.swift      # "Welcome back" sheet data
├── Services/
│   ├── SaveManager.swift          # UserDefaults persistence
│   ├── AdsManager.swift           # Rewarded-ad protocol (+ async bridge)
│   └── MockAdsManager.swift       # Fake ad until a real SDK is plugged in
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

## Plugging in a real ad SDK

Write a class that conforms to `AdsManager` and wraps your SDK's rewarded ad
(call `completion(true)` only when the reward is earned, and exactly once).
Then pass it in `MiniIdleTycoonApp.swift`:

```swift
@StateObject private var viewModel = GameEngineViewModel(adsManager: YourSDKAdsManager())
```

## Build phases

1. Models & math ✅
2. Game engine loop ✅
3. Offline earnings & persistence ✅
4. SwiftUI front end ✅
5. Monetization wrappers ✅
6. Progression: milestones, bulk buy, prestige ✅
