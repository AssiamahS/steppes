# Steppes

**Install:** open [assiamahs.github.io/steppes/install.html](https://assiamahs.github.io/steppes/install.html) in Safari on your iPhone.

Today's step count, pinned in the Dynamic Island.

- iPhone app (iOS 26, SwiftUI, Liquid Glass) with a progress ring, distance, floors and a daily goal.
- Live Activity in the Dynamic Island and on the Lock Screen (`SteppesWidgets`).
- Steps come from `CMPedometer` (motion coprocessor); HealthKit is the fallback source when Motion access is denied.
- Background refresh of the island: HealthKit background delivery for `stepCount` + a `BGAppRefreshTask` backstop (~15 min).

## Layout

```
project.yml                 XcodeGen spec (single source of truth — never edit the .xcodeproj)
Steppes/                    app target
  SteppesApp.swift          scene, background task hook, launch delegate
  StepStore.swift           pedometer + HealthKit + Live Activity + BG refresh
  ContentView.swift         UI
Shared/                     StepsActivityAttributes (app + widget)
SteppesWidgets/             Live Activity / Dynamic Island widget
.github/workflows/ci.yml    unsigned compile check, then cloud-signed archive → TestFlight
```

## Build

There is no local Xcode on the dev Mac; CI on `macos-26` compiles and uploads.
`CURRENT_PROJECT_VERSION` is stamped with the GitHub run number before `xcodegen generate`.

## Known limits

- iOS ends a Live Activity in the Dynamic Island after 8 hours; `Activity.request` is foreground-only, so reopen the app to restart it.
- Background updates depend on iOS granting HealthKit background delivery / app refresh; the count is always exact when the app is opened.
