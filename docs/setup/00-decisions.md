# Phase 1 — Decisions and Pre-Flight

This document captures every project-level decision needed before any Firebase
setup script or console configuration runs. Each decision has a chosen value,
rationale, and the SRS or ADR section it implements.

This file is the single source of truth for all setup phases that follow
(scripts, console checklist, store registration, secrets manifest). Changes to
any value here must be propagated to all downstream artefacts.

---

## 1. Project Identity

| Decision | Value | Rationale | Reference |
|---|---|---|---|
| Firebase project ID | `onebytwo-avtanshgupta` | Globally unique, immutable. Project already created by the stakeholder. | SRS section 9.1; invariant 4 |
| Display name | `One By Two` | Brand name per SRS. | SRS section 12.2 |
| Default GCP region (Firestore) | `asia-south1` (Mumbai) | Minimise latency for India-first user base. Region is immutable after database creation. | SRS section 5.2; deployment topology section 2 |
| Cloud Storage bucket region | `asia-south1` (Mumbai) | Co-located with Firestore for lowest latency on receipt image reads. | SRS section 5.2 |
| Cloud Functions region | `asia-south1` (Mumbai) | Hard-coded in every function definition. Co-located with Firestore to avoid cross-region charges. | SRS section 5.2; ADR-0005 |

---

## 2. App Identifiers

| Decision | Value | Rationale | Reference |
|---|---|---|---|
| iOS bundle identifier | `com.avtanshgupta.onebytwo` | Reverse-domain format matching developer identity. | SRS section 3.4 |
| Android application ID | `com.avtanshgupta.onebytwo` | Matches iOS bundle ID for consistency. | SRS section 3.4 |
| URL scheme (deep links) | `onebytwo://` | Custom URL scheme for in-app navigation. | SRS section 4.11 |
| Universal Link domain (iOS) | `links.onebytwo.app` | Placeholder. DNS must point to Firebase Hosting (or marketing site). `apple-app-site-association` (AASA) must be served at `/.well-known/apple-app-site-association` before Universal Links work end-to-end. | SRS section 4.11 |
| App Link domain (Android) | `links.onebytwo.app` | Same domain as iOS. `assetlinks.json` must be served at `/.well-known/assetlinks.json`. | SRS section 4.11 |

**Note:** Deep link domains are placeholders. DNS configuration and AASA/assetlinks.json hosting are deferred until the deep-link feature is implemented. The domain must be reserved but does not need to resolve at setup time.

---

## 3. Auth Posture

| Decision | Value | Rationale | Reference |
|---|---|---|---|
| Sign-in method | Phone Auth (only) | Per SRS, phone is the sole auth method for v1.0. No email, no social sign-in. | SRS section 3.4 |
| SMS region whitelist | India only (`IN`) | Block all non-Indian phone numbers to control SMS costs and abuse surface. | SRS section 3.4 |
| reCAPTCHA Enterprise | Enabled | Required for Phone Auth abuse prevention. Firebase uses reCAPTCHA Enterprise to verify that auth requests originate from legitimate app sessions. | SRS section 5.4 |
| Auth emulator project | `demo-onebytwo` | All pre-merge tests run against the emulator with this demo project ID. This is NOT the production project. | SRS section 9.1; invariant 4 |

---

## 4. App Check Posture

| Decision | Value | Rationale | Reference |
|---|---|---|---|
| iOS attestation provider | DeviceCheck | Reliable, available on all supported iOS versions. App Attest is available as a future upgrade but not required for v1.0. | SRS section 5.4 |
| Android attestation provider | Play Integrity | Standard attestation for Android. Requires the app to be registered in Play Console first. | SRS section 5.4 |
| Debug tokens | Enabled for development only | One debug token per developer machine. Tokens are stored in a shared vault (1Password), never in the repository. | SRS section 5.4 |
| Enforcement targets | Firestore, Storage, Cloud Functions | All three backend services require valid App Check tokens. | SRS section 5.4 |
| Enforcement rollout | "Allow with monitoring" for the first 48 hours post-launch, then "Enforce" | Gradual enforcement to catch any client-side integration issues before blocking traffic. | SRS section 11.2 |

---

## 5. Billing

| Decision | Value | Rationale | Reference |
|---|---|---|---|
| Billing plan | Blaze (pay-as-you-go) | Required for Cloud Functions, Phone Auth SMS, and Cloud Storage. The free Spark plan is insufficient. | SRS section 3.4 |
| Monthly budget cap | INR 5,000 (~$60 USD) | Conservative cap for the launch period. Covers SMS costs, function invocations, and storage. | Stakeholder decision |
| Budget alert thresholds | 50%, 90%, 100% of INR 5,000 | Alerts sent to the billing account owner at each threshold. At 100% an additional action alert is triggered. | Stakeholder decision |
| Billing account owner | avtanshgupta (sole owner) | Single point of responsibility for billing. | Stakeholder decision |

---

## 6. Observability

| Decision | Value | Rationale | Reference |
|---|---|---|---|
| Crashlytics | Enabled (iOS and Android) | Crash reporting for production builds. PII must never be logged. dSYM upload required for iOS symbolication. | SRS sections 5.4, 5.10 |
| Performance Monitoring | Enabled (iOS and Android) | Cold start, frame rendering, and network trace monitoring. | SRS section 5.10 |
| Analytics | Enabled (default property linked) | Core funnel events per telemetry plan. No PII, amounts bucketed. | SRS section 5.10; telemetry plan |
| Analytics data retention | 14 months (maximum) | Maximum allowed retention period for user-level data. | Firebase default max |
| BigQuery export | Deferred to v1.1 | Additional storage cost not justified for launch. Can be enabled later without code changes. | Stakeholder decision |

---

## 7. Remote Config Keys (Initial Set)

These keys are seeded at setup time and available to the client from first launch.

| Key | Type | Default Value | Purpose | Reference |
|---|---|---|---|---|
| `support_email` | `string` | `support@onebytwo.app` | Contact Support feature reads this address. Can be changed without an app update. | SRS section 4.11; ADR-0006 |
| `min_supported_app_version` | `string` | `1.0.0` | Force-upgrade threshold. Clients below this version see an "Update required" screen. | SRS section 9.4 |
| `feature_flags.simplify_debts_recompute_v2` | `boolean` | `false` | Kill switch placeholder for the simplified-debts recomputation algorithm. When `true`, the Cloud Function uses a v2 algorithm path (not yet implemented). | SRS section 9.4 |

---

## 8. Service Accounts

| Decision | Value | Rationale | Reference |
|---|---|---|---|
| CI deployer account | `github-actions-deployer@onebytwo-avtanshgupta.iam.gserviceaccount.com` | Dedicated service account for GitHub Actions CI/CD. Separation of duties: this account deploys but does not serve runtime requests. | SRS section 9.3 |
| Deployer IAM roles | `roles/firebase.admin`, `roles/cloudfunctions.admin`, `roles/firebaserules.admin`, `roles/iam.serviceAccountUser` | Minimum roles for deploying rules, indexes, Cloud Functions, and Remote Config. `firebase.admin` is broad — prefer narrowing to specific Firebase roles if feasible after v1.0 launch stabilises. | SRS section 9.3 |
| Cloud Functions runtime SA | Default Compute Engine service account | The runtime account is NOT the deployer account. Cloud Functions execute under the project's default service account, which has the Admin SDK access needed for Firestore, Storage, and FCM writes. | SRS section 5.4 |

**Note on role narrowing:** `roles/firebase.admin` is intentionally broad for initial setup simplicity. Post-launch, consider replacing it with the specific sub-roles: `roles/firebase.developAdmin`, `roles/datastore.indexAdmin`, and `roles/firebasehosting.admin`.

---

## 9. GitHub Secrets

All secret names match SRS section 9.3 verbatim. No additional or renamed secrets are introduced.

| Secret Name | Source | Format | Rotation Policy | Used By |
|---|---|---|---|---|
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Phase 2 script `08-create-deployer-sa.sh` output | JSON key file (raw JSON) | Rotate annually | PR pipeline, release pipeline (Firebase deploys via `google-github-actions/auth`) |
| `ANDROID_KEYSTORE_BASE64` | Phase 4 Android keystore creation | Base64-encoded `.jks` file | Do not rotate (bound to Play App Signing) | Release pipeline — Android build |
| `ANDROID_KEYSTORE_PASSWORD` | Phase 4 Android keystore creation | Plain text | Rotate only if compromised | Release pipeline — Android build |
| `KEY_ALIAS` | Phase 4 Android keystore creation | Plain text | Stable (matches keystore) | Release pipeline — Android build |
| `KEY_PASSWORD` | Phase 4 Android keystore creation | Plain text | Rotate only if compromised | Release pipeline — Android build |
| `PLAY_SERVICE_ACCOUNT_JSON` | Phase 4 Play Console service account | JSON key file (base64-encoded) | Rotate annually | Release pipeline — Play upload |
| `APP_STORE_CONNECT_API_KEY_ID` | Phase 4 App Store Connect API key | Plain text (key ID) | Rotate annually or on team change | Release pipeline — TestFlight upload |
| `ISSUER_ID` | Phase 4 App Store Connect API key | Plain text (issuer ID) | Stable (tied to team) | Release pipeline — TestFlight upload |
| `KEY_BASE64` | Phase 4 App Store Connect API key | Base64-encoded `.p8` file | Rotate annually | Release pipeline — TestFlight upload |
| `MATCH_GIT_URL` | Phase 4 Fastlane match repo setup | Git URL (SSH or HTTPS) | Stable | Release pipeline — iOS cert sync |
| `MATCH_PASSWORD` | Phase 4 Fastlane match repo setup | Plain text passphrase | Rotate annually | Release pipeline — iOS cert sync |
| `OPS_NOTIFY_WEBHOOK` | Slack/Teams webhook URL | URL | Rotate on channel change | Release pipeline — notifications |

---

## 10. Apple Developer Configuration

| Decision | Value | Rationale | Reference |
|---|---|---|---|
| Apple Team ID | `S6ULATL6PT` | Stakeholder-provided. Used for DeviceCheck, APNs, and code signing. | Stakeholder decision |
| Bundle ID | `com.avtanshgupta.onebytwo` | See section 2 above. | SRS section 3.4 |

---

## 11. Google Cloud APIs to Enable

The following APIs must be enabled on the `onebytwo-avtanshgupta` GCP project before any Firebase service can be configured:

| API | Service Identifier | Reason |
|---|---|---|
| Firebase Management | `firebase.googleapis.com` | Core Firebase project management |
| Firebase Auth (Identity Toolkit) | `identitytoolkit.googleapis.com` | Phone Auth sign-in |
| Cloud Firestore | `firestore.googleapis.com` | Primary data store |
| Firebase Remote Config | `firebaseremoteconfig.googleapis.com` | Feature flags and support email |
| Firebase Cloud Storage | `firebasestorage.googleapis.com` | Receipt images and avatars |
| Firebase Cloud Messaging | `fcm.googleapis.com` | Push notifications |
| Cloud Functions | `cloudfunctions.googleapis.com` | Serverless business logic |
| Cloud Build | `cloudbuild.googleapis.com` | Required by Cloud Functions deployment |
| Secret Manager | `secretmanager.googleapis.com` | Runtime secrets for Cloud Functions |
| reCAPTCHA Enterprise | `recaptchaenterprise.googleapis.com` | Phone Auth abuse prevention |

---

## 12. Items NOT Decided Here

These items are explicitly deferred or out of scope for this phase:

| Item | Status | Notes |
|---|---|---|
| Deep link DNS configuration | Deferred | Domain `links.onebytwo.app` is reserved as a placeholder. DNS, AASA, and assetlinks.json are configured when the deep-link feature is implemented. |
| BigQuery Analytics export | Deferred to v1.1 | Stakeholder decision. |
| Firebase Hosting marketing site | Out of scope | Hosting is reserved only for AASA/assetlinks.json; no marketing content. |
| App icons, splash screens, store listing assets | Out of scope | Separate design/marketing track. |
| Firestore Security Rules beyond default-deny | Deferred | Rules grow PR-by-PR with the features that need them. Only a default-deny baseline plus the user-doc allow rule is deployed at setup time. |
| Flutter or Cloud Functions application code | Out of scope | This session produces documentation and scripts only. |

---

## Approval

This document must be reviewed and approved by the stakeholder before Phase 2
(CLI setup scripts) begins.

| Reviewer | Status | Date |
|---|---|---|
| avtanshgupta (stakeholder) | `Approved` | 2026-05-01 |
