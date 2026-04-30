# Readiness for Skeleton PR

This checklist must be fully satisfied before the skeleton bootstrap PR can be
opened. Each item maps to a setup phase and references the SRS or decisions
document for traceability.

Source of truth: `docs/setup/00-decisions.md`.

---

## Firebase Project

- [x] Firebase project `onebytwo-avtanshgupta` created and accessible.
  — Phase 1; SRS section 9.1; invariant 4

- [x] Blaze (pay-as-you-go) billing enabled.
  — Phase 1; SRS section 3.4. Billing account: `billingAccounts/01C75D-33BD32-C1C732`

- [x] Budget alerts configured: 50%, 90%, 100% of INR 5,000/month.
  — Console checklist 3.1.2; docs/setup/00-decisions.md section 5

## Firestore

- [x] Firestore database exists in `asia-south1`, Native mode.
  — Script `03-create-firestore.sh`; SRS section 5.2. Created 2026-04-30.

## Cloud Storage

- [x] Default Storage bucket exists in `asia-south1`.
  — Bucket: `onebytwo-avtanshgupta.firebasestorage.app` (ASIA-SOUTH1)

## Authentication

- [ ] Phone Auth enabled as the ONLY sign-in provider.
  — Console checklist 3.2.1; SRS section 3.4

- [ ] SMS region whitelist set to India only (`IN`).
  — Console checklist 3.2.2; SRS section 3.4

- [ ] reCAPTCHA Enterprise enabled for Phone Auth.
  — Console checklist 3.2.3; SRS section 5.4

## App Check

- [ ] iOS: DeviceCheck provider registered. Apple Team ID `S6ULATL6PT` and
  DeviceCheck key uploaded.
  — Console checklist 3.3.1; SRS section 5.4. API registration deferred to Console.

- [ ] Android: Play Integrity provider registered.
  — Console checklist 3.3.2; SRS section 5.4. API registration deferred to Console.

- [ ] Debug token(s) issued for local development. Stored in 1Password.
  — Console checklist 3.3.4

## App Registration

- [x] iOS app registered with Firebase (`com.avtanshgupta.onebytwo`).
  `GoogleService-Info.plist` downloaded to `scripts/firebase/_artifacts/`.
  — App ID: `1:1013666369675:ios:94662373479ee2022d848e`

- [x] Android app registered with Firebase (`com.avtanshgupta.onebytwo`).
  `google-services.json` downloaded to `scripts/firebase/_artifacts/`.
  — App ID: `1:1013666369675:android:ac4be3f4594d88f62d848e`

## App Store Connect

- [ ] App record exists in App Store Connect with bundle ID `com.avtanshgupta.onebytwo`.
  — Phase 4 section 4.1

- [ ] APNs Authentication Key created and uploaded to Firebase (FCM config).
  — Phase 4 section 4.2; console checklist 3.4.2

## Google Play Console

- [ ] App record exists in Play Console with application ID `com.avtanshgupta.onebytwo`.
  — Phase 4 section 4.7

## Service Account

- [x] Deployer service account
  `github-actions-deployer@onebytwo-avtanshgupta.iam.gserviceaccount.com`
  exists with minimum IAM roles: `firebase.admin`, `cloudfunctions.admin`,
  `firebaserules.admin`, `iam.serviceAccountUser`.
  — Script `08-create-deployer-sa.sh`; JSON key in `_artifacts/`.

## Remote Config

- [x] Initial Remote Config keys seeded: `support_email`,
  `min_supported_app_version`, `feature_flags.simplify_debts_recompute_v2`.
  — Script `06-seed-remote-config.sh`; SRS section 9.4

## GitHub Secrets

- [ ] All secrets from SRS section 9.3 uploaded to GitHub Actions.
  **Uploaded so far:**
  - [x] `FIREBASE_SERVICE_ACCOUNT_JSON` — uploaded 2026-05-01
  **Remaining (require manual credential creation first):**
  - [ ] `ANDROID_KEYSTORE_BASE64` — requires keystore from Phase 4 section 4.3
  - [ ] `ANDROID_KEYSTORE_PASSWORD` — requires keystore from Phase 4 section 4.3
  - [ ] `KEY_ALIAS` — requires keystore from Phase 4 section 4.3
  - [ ] `KEY_PASSWORD` — requires keystore from Phase 4 section 4.3
  - [ ] `PLAY_SERVICE_ACCOUNT_JSON` — requires Play Console SA from Phase 4 section 4.5
  - [ ] `APP_STORE_CONNECT_API_KEY_ID` — requires API key from Phase 4 section 2.5
  - [ ] `ISSUER_ID` — requires API key from Phase 4 section 2.5
  - [ ] `KEY_BASE64` — requires API key from Phase 4 section 2.5
  - [ ] `MATCH_GIT_URL` — requires match repo from Phase 4 section 2.6
  - [ ] `MATCH_PASSWORD` — requires match repo from Phase 4 section 2.6
  - [ ] `OPS_NOTIFY_WEBHOOK` — requires Slack/Teams webhook creation

## Repo Configuration

- [x] `.firebaserc` updated with project ID `onebytwo-avtanshgupta`.
  — Phase 6 section 6.1

- [x] `firebase.json` emulator ports and project default confirmed.
  — Phase 6 section 6.3

- [x] `release.yml` deploy steps include `--project onebytwo-avtanshgupta`.
  — Phase 6 section 6.2

- [x] `firestore.rules`, `firestore.indexes.json`, `storage.rules` deployed.
  — Script `05-deploy-rules-and-indexes.sh`. Default-deny baseline.

## Smoke Test

- [x] `scripts/firebase/10-smoke-test.sh` passes against production
  (Firestore write/read/delete succeeds). Verified 2026-05-01.

## Stakeholder Confirmation

- [ ] Stakeholder has reviewed budget alerts and confirmed the billing owner.
  — docs/setup/00-decisions.md section 5

---

## QA Sign-Off

This section is completed by the QA agent after reviewing the checklist above
against SRS section 11.2 (Launch Readiness Checklist).

| Reviewer | Verdict | Date | Notes |
|---|---|---|---|
| QA agent | `PENDING` | — | — |

**QA review scope:** Verify every item above is checked. Cross-reference
against SRS section 11.2 to confirm no launch-readiness item is missed at
the infrastructure level. Items that are feature-dependent (e.g., "all P0
functional requirements implemented") are out of scope for this
infrastructure-readiness checklist and will be verified separately.
