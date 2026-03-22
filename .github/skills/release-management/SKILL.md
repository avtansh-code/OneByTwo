---
name: release-management
description: "Version strategy, changelog format, Fastlane configuration, and release checklist for deploying One By Two to Google Play Store and Apple App Store."
---

# Release Management

## Version Strategy

| Component | Format | Example |
|-----------|--------|---------|
| Version | SemVer `MAJOR.MINOR.PATCH` | `1.2.3` |
| Build number | Auto-incrementing integer | `42` |
| Flutter pubspec | `version: MAJOR.MINOR.PATCH+BUILD` | `version: 1.2.3+42` |

### When to Bump

| Level | When | Example |
|-------|------|---------|
| **MAJOR** | Breaking changes requiring data migration | Schema v1 → v2, auth flow rewrite |
| **MINOR** | New features (backward compatible) | Add itemized splitting, friend search |
| **PATCH** | Bug fixes, performance improvements | Fix rounding error, improve list scroll |

### Build Number

- Always increment build number on every release (even for same version).
- Android: `versionCode` in `build.gradle` (must be strictly increasing).
- iOS: `CFBundleVersion` (must be strictly increasing per version).
- Managed via `pubspec.yaml` `version` field — Flutter propagates to both platforms.

---

## Changelog Format

Follow [Keep a Changelog](https://keepachangelog.com/) with Conventional Commits prefixes:

```markdown
# Changelog

## [Unreleased]

### Added
- feat(friends): Add friend by phone number search

## [1.2.0] - 2026-03-22

### Added
- feat(friends): Add friend by phone number search
- feat(settlements): Settle All with optimized plan

### Changed
- refactor(expenses): Improve split algorithm performance

### Fixed
- fix(balances): Correct rounding in 3-way equal split
- fix(sync): Handle conflict resolution for offline edits

### Security
- security(rules): Add rate limiting to invite joins

## [1.1.0] - 2026-02-15

### Added
- feat(analytics): Monthly spending breakdown chart
```

### Section Order

1. **Added** — New features
2. **Changed** — Changes to existing features
3. **Deprecated** — Features to be removed in future
4. **Removed** — Removed features
5. **Fixed** — Bug fixes
6. **Security** — Security-related changes

---

## Fastlane Configuration

### Android (`android/fastlane/Fastfile`)

```ruby
default_platform(:android)

platform :android do
  desc "Deploy to Google Play internal track"
  lane :internal do
    upload_to_play_store(
      track: 'internal',
      aab: '../build/app/outputs/bundle/release/app-release.aab',
      json_key: 'play-store-key.json',
      package_name: 'com.onebytwo.app'
    )
  end

  desc "Promote internal to beta"
  lane :beta do
    upload_to_play_store(
      track: 'internal',
      track_promote_to: 'beta',
      skip_upload_aab: true,
      json_key: 'play-store-key.json',
      package_name: 'com.onebytwo.app'
    )
  end

  desc "Promote beta to production"
  lane :production do
    upload_to_play_store(
      track: 'beta',
      track_promote_to: 'production',
      skip_upload_aab: true,
      json_key: 'play-store-key.json',
      package_name: 'com.onebytwo.app'
    )
  end
end
```

### iOS (`ios/fastlane/Fastfile`)

```ruby
default_platform(:ios)

platform :ios do
  desc "Deploy to TestFlight"
  lane :beta do
    upload_to_testflight(
      ipa: '../build/ios/ipa/OneByTwo.ipa',
      skip_waiting_for_build_processing: true
    )
  end

  desc "Promote to App Store"
  lane :release do
    deliver(
      submit_for_review: true,
      automatic_release: false,
      force: true
    )
  end
end
```

---

## Release Checklist

### Pre-Release

- [ ] All CI checks passing on `main` branch
- [ ] Version bumped in `pubspec.yaml`
- [ ] Build number incremented
- [ ] `CHANGELOG.md` updated with all changes since last release
- [ ] No TODO/FIXME remaining for current release items
- [ ] Architecture docs up to date
- [ ] All P0/P1 items completed and tested
- [ ] Manual QA pass on physical device (Android + iOS)
- [ ] Offline scenarios tested (add expense offline → sync)
- [ ] Hindi localization reviewed for new strings

### Build

- [ ] `flutter clean`
- [ ] `flutter pub get`
- [ ] `flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info`
- [ ] `flutter build ipa --release`
- [ ] Upload debug symbols to Firebase Crashlytics
- [ ] Verify APK size < 30MB
- [ ] Verify IPA size within App Store limits

### Deploy Backend (if changed)

- [ ] `firebase deploy --only functions --project prod`
- [ ] `firebase deploy --only firestore:rules --project prod`
- [ ] `firebase deploy --only firestore:indexes --project prod`
- [ ] Smoke test Cloud Functions (create expense, settle, invite)
- [ ] Verify security rules with `firebase emulators:exec`

### Deploy App

- [ ] Android: `cd android && fastlane internal`
- [ ] iOS: `cd ios && fastlane beta`
- [ ] Verify builds appear in Google Play Console / App Store Connect
- [ ] Install from internal track / TestFlight on test device
- [ ] Run smoke tests on installed build

### Post-Release

- [ ] Monitor Firebase Crashlytics for new crashes (first 24h)
- [ ] Monitor Firebase Analytics for usage anomalies
- [ ] Check Cloud Functions error rates in GCP Console
- [ ] Create GitHub Release with tag `v{MAJOR}.{MINOR}.{PATCH}`
- [ ] Attach release notes from CHANGELOG
- [ ] Announce release in team channel
- [ ] Promote to production after 48h soak on internal/beta (if stable)

---

## Rollback Procedure

### App Rollback

1. Revert the version bump commit on `main`.
2. Google Play: Halt rollout in Play Console → promote previous version.
3. App Store: Remove current version from sale → previous version remains available.
4. Notify users via in-app banner if critical.

### Backend Rollback

```bash
# Rollback Cloud Functions to previous version
firebase functions:log --only <functionName>  # Check for errors first
gcloud functions deploy <functionName> --source=gs://...  # Redeploy previous

# Rollback Firestore rules
firebase deploy --only firestore:rules --project prod
# (from a commit with the previous rules version)
```

### Data Migration Rollback

- If a batch migration was run, prepare and test a reverse migration **before** running the forward migration.
- Keep `schemaVersion` tracking to know which documents have been migrated.
