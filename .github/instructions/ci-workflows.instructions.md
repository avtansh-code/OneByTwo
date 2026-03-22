---
applyTo: ".github/workflows/**/*.yml"
---

# GitHub Actions Workflow Instructions

## General

- Pin Flutter version: `subosito/flutter-action@v2` with `flutter-version: '3.x.x'` or `channel: 'stable'`
- Pin Node version: `actions/setup-node@v4` with `node-version: '20'`
- Use `actions/cache@v4` for pub cache (`~/.pub-cache`) and npm cache
- Use `concurrency` groups to cancel outdated runs: `concurrency: { group: ${{ github.workflow }}-${{ github.ref }}, cancel-in-progress: true }`
- Use `--no-pub` after first `flutter pub get` to avoid redundant fetches

## Job Order

1. `analyze-and-format` (fast, catches obvious issues first)
2. `test-and-coverage` (depends on analyze passing)
3. `security-scan` (parallel with test)
4. `architecture-compliance` (parallel with test)
5. `cloud-functions-check` (parallel with Flutter jobs)
6. `firestore-rules-test` (parallel with Flutter jobs)
7. `build-check` (last, most expensive)

## Secrets Management

- NEVER hardcode secrets in workflow files
- Use `${{ secrets.SECRET_NAME }}` for sensitive values
- Firebase service account key: `FIREBASE_SERVICE_ACCOUNT`
- Play Store key: `PLAY_STORE_KEY`
- App Store Connect: `APP_STORE_CONNECT_KEY`

## Android Build

- Build AAB (not APK) for Play Store: `flutter build appbundle --release`
- Enable obfuscation: `--obfuscate --split-debug-info=build/debug-info`
- Upload debug symbols to Crashlytics

## iOS Build

- Build IPA: `flutter build ipa --release --export-options-plist=ios/ExportOptions.plist`
- Handle signing with `match` or manual provisioning

## PR-Only Enforcement

All CI pipelines are designed around the PR workflow:

- `ci-pr.yml` triggers on `pull_request` targeting `main` or `develop`
- Branch protection requires all 7 jobs to pass before merge
- Direct pushes to `main` and `develop` are blocked

**Required status checks for merge:**

```yaml
required_status_checks:
  - analyze-and-format
  - test-and-coverage
  - security-scan
  - architecture-compliance
  - cloud-functions-check
  - firestore-rules-test
  - build-check
```

**Concurrency:** Cancel outdated runs when new commits are pushed to the same PR:

```yaml
concurrency:
  group: pr-${{ github.event.pull_request.number }}
  cancel-in-progress: true
```

## Caching

```yaml
- uses: actions/cache@v4
  with:
    path: |
      ~/.pub-cache
      .dart_tool/
    key: pub-${{ hashFiles('pubspec.lock') }}
    restore-keys: pub-
```
