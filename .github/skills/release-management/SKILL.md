---
name: release-management
description: Guide for managing releases of the One By Two app — version bumping, changelog generation, Fastlane configuration, store metadata, and release workflow.
---

## Release Process Overview

```
Code Complete → Version Bump → Changelog → Build → Test → Deploy → Store Release
```

## Version Strategy

Follow **Semantic Versioning** with build number:

```yaml
# pubspec.yaml
version: 1.2.3+45
#        │ │ │  └─ Build number (increments every build, used by stores)
#        │ │ └──── Patch (bug fixes)
#        │ └────── Minor (new features, backward compatible)
#        └──────── Major (breaking changes)
```

**Version bump rules:**
- Sprint completion with new features → **minor** bump
- Bug fix release → **patch** bump
- Phase transition (MVP → Enhanced) → **major** bump
- Build number always increments (never resets)

## Changelog (CHANGELOG.md)

Follow [Keep a Changelog](https://keepachangelog.com/) format:

```markdown
# Changelog

## [1.2.0] - 2026-03-15

### Added
- Itemized bill splitting — assign individual items to specific people (EX-03)
- Receipt photo attachment to expenses (EX-08)

### Changed
- Improved balance recalculation performance for large groups

### Fixed
- Split remainder not distributed correctly for 3-way splits (#142)
- Sync stuck in pending state after airplane mode (#155)

## [1.1.0] - 2026-02-28
...
```

## Version Bump Commands

```bash
# Bump version in pubspec.yaml
# Manual: edit pubspec.yaml version field

# Verify version
grep "^version:" pubspec.yaml

# Update build number (CI typically auto-increments)
# Format: version: MAJOR.MINOR.PATCH+BUILD_NUMBER
```

## Store Release Configuration

### Android (Google Play)

```
android/
├── app/
│   ├── build.gradle          # versionCode, versionName, signing
│   └── src/
│       ├── main/             # Production
│       ├── staging/          # Staging flavor
│       └── dev/              # Dev flavor
├── fastlane/
│   ├── Fastfile             # Lane definitions
│   └── metadata/android/
│       └── en-US/
│           ├── title.txt             # "One By Two"
│           ├── short_description.txt # "Split expenses. Not friendships."
│           ├── full_description.txt  # Store listing
│           └── changelogs/
│               └── 45.txt            # What's new for build 45
```

### iOS (App Store Connect)

```
ios/
├── Runner.xcodeproj/         # Xcode project (version, build, signing)
├── fastlane/
│   ├── Fastfile             # Lane definitions
│   └── metadata/
│       └── en-US/
│           ├── name.txt
│           ├── subtitle.txt
│           ├── description.txt
│           ├── keywords.txt
│           ├── release_notes.txt
│           └── privacy_url.txt
```

## Fastlane Configuration

### Android Fastfile

```ruby
default_platform(:android)

platform :android do
  desc "Deploy to internal testing track"
  lane :internal do
    gradle(task: "clean assembleRelease")
    upload_to_play_store(track: "internal")
  end

  desc "Promote internal to production"
  lane :release do
    upload_to_play_store(
      track: "internal",
      track_promote_to: "production",
      rollout: "0.1"  # 10% rollout
    )
  end
end
```

### iOS Fastfile

```ruby
default_platform(:ios)

platform :ios do
  desc "Deploy to TestFlight"
  lane :beta do
    build_app(scheme: "Runner")
    upload_to_testflight
  end

  desc "Submit to App Store"
  lane :release do
    deliver(
      submit_for_review: true,
      automatic_release: false
    )
  end
end
```

## Release Checklist

### Pre-Release
- [ ] All sprint tasks marked done
- [ ] All P0 tests passing (unit, widget, integration)
- [ ] `flutter analyze` — zero warnings
- [ ] Code coverage meets targets (80%+ domain, 100% algorithms)
- [ ] No `conflict` items in sync queue test scenarios
- [ ] Changelog updated with all changes
- [ ] Version bumped in `pubspec.yaml`
- [ ] Build number incremented

### Build & Deploy
- [ ] `flutter build appbundle --release` (Android)
- [ ] `flutter build ipa --release` (iOS)
- [ ] App size < 30MB verified
- [ ] Signed with production certificates
- [ ] Firebase project pointing to production
- [ ] Cloud Functions deployed to production
- [ ] Firestore security rules deployed
- [ ] Store metadata and screenshots updated

### Post-Release
- [ ] Monitor Crashlytics for new crashes (first 24h)
- [ ] Monitor Firebase Analytics for usage anomalies
- [ ] Check sync success rate (> 99.9%)
- [ ] Update `09_IMPLEMENTATION_PLAN.md` sprint status
- [ ] Tag release in git: `git tag -a v1.2.0 -m "Release 1.2.0"`
- [ ] Create GitHub Release with changelog

## CI/CD Release Workflow

Releases triggered by git tags matching `v*`:

```yaml
# .github/workflows/release.yml
on:
  push:
    tags: ['v*']

jobs:
  build-and-deploy:
    # Build APK/IPA, run tests, deploy to stores
```

## Reference

- Implementation plan: `docs/architecture/09_IMPLEMENTATION_PLAN.md`
- Architecture (CI/CD): `docs/architecture/01_ARCHITECTURE_OVERVIEW.md`
