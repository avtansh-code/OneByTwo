# DevOps Readiness Checklist

## Overview

This checklist enumerates everything that must be true in the production Firebase
project and in GitHub before sprint 1 can ship a build to any track.

All items reference the authoritative SRS (`docs/OneByTwo_Requirements_Spec.md`
v1.1) and the repository invariants (`.github/shared/invariants.md`). Per
**invariant 4**, there is exactly one Firebase project (production). All
pre-merge testing runs against the Firebase Emulator Suite; no staging or
development projects may be created.

---

## Firebase Project Configuration

| # | Item | Detail | Status |
|---|------|--------|--------|
| 1 | Phone Auth enabled with +91 restriction | Firebase Authentication provider set to Phone; sign-in restricted to `+91` numbers only. (SRS 3.4, 4.1) | TODO |
| 2 | Firestore created in `asia-south1` region | Cloud Firestore instance provisioned in `asia-south1` (Mumbai). Region is immutable after creation. (SRS 7.1) | TODO |
| 3 | Firestore Security Rules deployed | Initial permissive rules for development deployed via Firebase CLI. Must be locked down before GA. Must enforce `simplifiedBalances` as client-read-only (invariant 2). (SRS 7.5, 9.4) | TODO |
| 4 | Cloud Storage bucket created in `asia-south1` | Default Storage bucket provisioned in `asia-south1` for profile photos and receipt images. (SRS 7.1) | TODO |
| 5 | App Check configured -- Play Integrity (Android) | Firebase App Check enforcement enabled for Android using the Play Integrity provider. (SRS 5.4, 11.2) | TODO |
| 6 | App Check configured -- DeviceCheck (iOS) | Firebase App Check enforcement enabled for iOS using the DeviceCheck (or App Attest) provider. (SRS 5.4, 11.2) | TODO |
| 7 | Firebase Cloud Messaging (FCM) configured | FCM enabled; APNs key uploaded for iOS; server key available for Cloud Functions. (SRS 4.7) | TODO |
| 8 | Firebase Crashlytics enabled (iOS + Android) | Crashlytics SDK initialised and dashboard accessible for both platforms. (SRS 5.10, 11.2) | TODO |
| 9 | Firebase Analytics enabled | Analytics collection enabled; dashboards reviewed. (SRS 5.10, 11.2) | TODO |
| 10 | Firebase Remote Config initialised with `support_email_address` key | Remote Config created with default value for `support_email_address` (per ADR-0006 and SRS 4.11, 12.2). Feature flags for critical features also initialised. (SRS 9.4) | TODO |
| 11 | Cloud Functions deployed to `asia-south1` region | All Cloud Functions (including `recomputeSimplifiedBalances`) deployed to `asia-south1`. Runtime: Node 20, TypeScript. (SRS 7.1, 7.4) | TODO |
| 12 | Billing alerts configured | Budget alerts set on the Firebase/GCP project to guard against unexpected charges. Thresholds aligned with projected usage. (SRS 11.2) | TODO |

---

## GitHub Repository Configuration

| # | Item | Detail | Status |
|---|------|--------|--------|
| 1 | Branch protection on `main` | No direct pushes, no force-pushes, require at least one approving PR review, require status checks to pass before merge. (SRS 8.3, 9.4) | TODO |
| 2 | Required status checks configured | PR pipeline (`pr.yml`) must pass before merge to `main`. (SRS 9.2.1, 9.4) | TODO |
| 3 | Signed commits required | All commits merged to `main` must be signed (GPG or SSH). (SRS 9.4) | TODO |
| 4 | GitHub Environment: `production-firebase` | Requires manual approval from the Architect agent before Firebase backend deployments (rules, indexes, Cloud Functions). (SRS 9.4) | TODO |
| 5 | GitHub Environment: `production-ios` | Requires manual approval from the QA agent before TestFlight / App Store promotion. (SRS 9.4) | TODO |
| 6 | GitHub Environment: `production-android` | Requires manual approval from the QA agent before Play Store promotion. (SRS 9.4) | TODO |

---

## GitHub Secrets

All secrets are stored in GitHub Actions encrypted secrets. Secrets must **never**
appear in source code (invariants, SRS 5.4).

| Secret | Purpose | Status |
|--------|---------|--------|
| `FIREBASE_TOKEN` | CI deploy of Firestore rules, indexes, and Cloud Functions via the Firebase CLI. (SRS 9.2.2, 9.3) | TODO |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Alternative credential for Firebase Admin SDK usage in CI integration tests. (SRS 9.3) | TODO |
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded Android release signing keystore (`.jks`). Used by Fastlane to sign the `.aab`. (SRS 9.3) | TODO |
| `ANDROID_KEYSTORE_PASSWORD` | Password for the Android keystore file. (SRS 9.3) | TODO |
| `KEY_ALIAS` | Alias of the signing key within the Android keystore. (SRS 9.3) | TODO |
| `KEY_PASSWORD` | Password for the signing key entry within the Android keystore. (SRS 9.3) | TODO |
| `PLAY_SERVICE_ACCOUNT_JSON` | Google Play Developer API service account JSON; used by Fastlane `supply` to upload the `.aab` to the Internal Track. (SRS 9.3) | TODO |
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API key identifier for TestFlight uploads. (SRS 9.3) | TODO |
| `ISSUER_ID` | App Store Connect API issuer ID. (SRS 9.3) | TODO |
| `KEY_BASE64` | Base64-encoded App Store Connect API private key (`.p8`). (SRS 9.3) | TODO |
| `MATCH_GIT_URL` | URL of the private Git repository used by Fastlane `match` for iOS certificate and provisioning profile storage. (SRS 9.3) | TODO |
| `MATCH_PASSWORD` | Encryption password for the Fastlane `match` repository. (SRS 9.3) | TODO |
| `OPS_NOTIFY_WEBHOOK` | Slack or Teams incoming-webhook URL for automated release and deployment notifications. (SRS 9.3) | TODO |

---

## CI/CD Pipelines

| # | Item | Detail | Status |
|---|------|--------|--------|
| 1 | PR pipeline (`.github/workflows/pr.yml`) | Trigger: `pull_request` to `main`. Steps: checkout, setup Flutter, setup Node 20, `flutter pub get`, `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test --coverage`, Cloud Functions lint and test (`cd functions && npm ci && npm run lint && npm test`), Firebase Emulator integration tests (including simplified-debts canonical cases), coverage gate (>= 70% non-UI, >= 50% overall, 100% branch on simplified-debts), unsigned builds for iOS and Android. (SRS 9.2.1; test-strategy.md) | TODO |
| 2 | Release pipeline (`.github/workflows/release.yml`) | Trigger: tag `v*.*.*` on `main` or `workflow_dispatch`. Steps: full test suite re-run, deploy Firestore rules/indexes/Cloud Functions to production (via `FIREBASE_TOKEN`), signed Android `.aab` via Fastlane to Play Internal Track, signed iOS `.ipa` via Fastlane `match` to TestFlight, manual promotion step via GitHub Environments, post-deploy smoke test and GitHub Release with auto-generated notes. Retain release artifacts for 90 days. (SRS 9.2.2, 9.4) | TODO |
| 3 | Firebase Emulator Suite configured for CI | `firebase.json` includes emulator configuration for Auth, Firestore, Functions, and Storage. Emulators start in CI for integration tests. (SRS 8.1, 9.2.1) | TODO |

---

## Local Development

| # | Item | Detail | Status |
|---|------|--------|--------|
| 1 | `firebase.json` with emulator configuration | Emulators for Auth, Firestore, Functions, and Storage configured with localhost ports. (SRS 8.1) | TODO |
| 2 | `.firebaserc` with single project alias | Exactly one project alias (`default` pointing to the production project ID). No additional project IDs permitted (invariant 4). (SRS 9.1) | TODO |
| 3 | `lefthook.yml` with pre-commit hooks | Pre-commit hooks run: `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test`, and Cloud Functions lint. (SRS 8.1) | TODO |

---

## References

- SRS: `docs/OneByTwo_Requirements_Spec.md` (v1.1), sections 3.4, 3.5, 8, 9, 11.2.
- Invariants: `.github/shared/invariants.md`.
- Test strategy: `.github/shared/test-strategy.md`.
- Decision log: `.github/shared/decision-log.md` (ADR-0006 for Remote Config).
