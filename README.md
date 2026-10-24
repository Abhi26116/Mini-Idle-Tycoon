# Mini-Idle-Tycoon
Mini Idle Tycoon game

A SwiftUI idle tycoon (theme: Startup Studio) built with MVVM and Swift Concurrency. Targets iOS 17+.

## Project structure

```
MiniIdleTycoon/
├── Models/
│   ├── Station.swift        # Station data + starting lineup
│   └── PlayerProfile.swift  # Coins & gems wallet
└── Utilities/
    └── GameMath.swift       # Cost / revenue formulas
```

## Using in Xcode

Create an iOS App project (Interface: SwiftUI), then drag the folders inside
`MiniIdleTycoon/` into the project navigator and make sure your app target is
checked.

## Build phases

1. Models & math ✅
2. Game engine loop
3. Offline earnings & persistence
4. SwiftUI front end
5. Monetization wrappers
