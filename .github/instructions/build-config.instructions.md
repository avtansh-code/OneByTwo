---
applyTo: "android/**/*.gradle,android/**/*.gradle.kts,android/**/AndroidManifest.xml,ios/**/*.plist,ios/**/*.pbxproj,ios/**/Podfile"
---

# Build Configuration Instructions

## Android
- `minSdk = 35` (Android 15) — user requirement, do not lower
- `targetSdk = 35` — always target latest stable
- `compileSdk = 35`
- Enable R8/ProGuard for release builds (`minifyEnabled true`, `shrinkResources true`)
- Use `ndkVersion` matching Flutter's expected version
- Signing config: Use `signingConfigs` block referencing `key.properties` (NOT committed to git)
- Three build flavors: `dev`, `staging`, `prod` — each pointing to its own Firebase project
- Each flavor has its own `google-services.json` in `app/src/{flavor}/`
- `google-services.json` must NOT be committed — listed in `.gitignore`

## iOS
- Minimum deployment target: iOS 17.0 — do not lower
- Set in both `Runner.xcodeproj` and `Podfile` (`platform :ios, '17.0'`)
- Code signing: Use automatic signing for development, manual for distribution
- Provisioning profiles managed via Fastlane Match
- Each build scheme (Dev, Staging, Prod) uses its own `GoogleService-Info.plist`
- `GoogleService-Info.plist` must NOT be committed — listed in `.gitignore`
- Enable bitcode: NO (Flutter does not support bitcode)

## Shared
- App identifier: Use reverse domain notation (e.g., `com.onebytwo.app`)
- Increment build number on every CI build (`versionCode` / `CFBundleVersion`)
- Never hardcode version — read from `pubspec.yaml` version field
