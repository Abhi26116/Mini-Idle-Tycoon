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

## Using in Xcode

1. Create a new project: **iOS → App**, Interface **SwiftUI**, product name `MiniIdleTycoon`.
2. Delete the template's `MiniIdleTycoonApp.swift` and `ContentView.swift` (Move to Trash).
3. Drag everything inside this repo's `MiniIdleTycoon/` folder into the project
   navigator, with your app target checked.
4. Set the deployment target to iOS 17.0 or later, then build and run.

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
