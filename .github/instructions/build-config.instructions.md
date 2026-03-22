---
applyTo: "android/**/*.gradle,android/**/*.gradle.kts,android/**/*.properties,ios/**/*.plist,ios/**/*.pbxproj,ios/Podfile"
---

# Android and iOS Build Configuration Instructions

## Android

- `minSdk`: 35 (Android 15+)
- `compileSdk`: 35
- `targetSdk`: 35
- R8/ProGuard: enabled for release builds (minification + obfuscation)
- Build flavors: `dev`, `staging`, `prod` (each with own Firebase config)
- Firebase config (`google-services.json`): NOT committed to git. Added via CI secrets or local `.gitignore`.
- Signing config: keystore path from `key.properties` (not committed)
- ProGuard rules: Keep Firebase, Flutter, and JSON serialization classes
- NDK: Not required (pure Dart + Firebase)

## iOS

- Minimum deployment target: iOS 17.0
- Swift version: 5.0+
- CocoaPods for dependencies
- Firebase config (`GoogleService-Info.plist`): NOT committed to git. Per-flavor via build phases.
- Signing: Automatic managed by Xcode or Fastlane `match`
- Build flavors: `dev`, `staging`, `prod` (via Xcode schemes)
- Bitcode: disabled (Flutter doesn't support it)
- App Transport Security: default (HTTPS only)

## Both Platforms

- 3 build flavors: `dev` (emulators, debug), `staging` (test Firebase project), `prod` (production Firebase)
- Each flavor has its own Firebase project configuration
- Never commit Firebase config files — add to `.gitignore`
- App bundle identifier: `com.onebytwo.app` (prod), `com.onebytwo.app.staging`, `com.onebytwo.app.dev`
