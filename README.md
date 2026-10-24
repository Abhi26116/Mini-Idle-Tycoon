# Mini-Idle-Tycoon
Mini Idle Tycoon game

A SwiftUI idle tycoon (theme: Startup Studio) built with MVVM and Swift Concurrency. Targets iOS 17+.

## Project structure

```
MiniIdleTycoon/
├── MiniIdleTycoonApp.swift        # @main entry, ScenePhase → save / offline earnings
├── Models/
│   ├── Station.swift              # Station data + starting lineup
│   ├── PlayerProfile.swift        # Coins & gems wallet
│   └── OfflineEarnings.swift      # "Welcome back" sheet data
├── Services/
│   ├── SaveManager.swift          # UserDefaults persistence
│   ├── AdsManager.swift           # Rewarded-ad protocol (+ async bridge)
│   └── MockAdsManager.swift       # Fake ad until a real SDK is plugged in
├── Utilities/
│   ├── GameMath.swift             # Cost / revenue / offline formulas
│   ├── Haptics.swift              # UIImpactFeedbackGenerator wrapper
│   └── NumberFormatting.swift     # 12345 → "12.35K"
├── ViewModels/
│   ├── GameEngineViewModel.swift  # Game loop, purchases, offline earnings
│   └── StationRowState.swift      # Precomputed per-row display state
└── Views/
    ├── MainGameView.swift         # Currency header + station list
    ├── StationRowView.swift       # One station card
    ├── OfflineEarningsView.swift  # Offline earnings sheet
    └── ProfitBoostView.swift      # "2X Profit Boost Active" banner / ad button
```

## Running on your iPhone

Requires Xcode 16 or later.

1. Open `MiniIdleTycoon.xcodeproj`.
2. Select the **MiniIdleTycoon** target → **Signing & Capabilities** → pick your
   Apple ID under **Team** (add it first in Xcode → Settings → Accounts).
3. Plug in your iPhone, pick it in the device menu at the top, press **⌘R**.

First time on a device: enable **Settings → Privacy & Security → Developer Mode**
on the iPhone, and after installing, trust your profile under
**Settings → General → VPN & Device Management**.

The project uses a synchronized folder, so new files added to `MiniIdleTycoon/`
are picked up automatically. Every push is also built on a macOS runner by
`.github/workflows/ios-build.yml`.

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
