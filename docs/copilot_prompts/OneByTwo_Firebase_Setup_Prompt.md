You are the One By Two orchestrator agent. The agentic workspace under .github/ is configured and smoke-tested. The SRS, sprint-zero artefacts, and design phase are all complete. We are now configuring the Firebase production project AND registering the iOS and Android apps with their respective stores. This must happen BEFORE the skeleton bootstrap PR.

The output of this session is documentation and scripts only. You will produce no Flutter or Cloud Functions application code. The end state is a Firebase production project that the skeleton PR can immediately point at, plus app-store registrations that hold the bundle identifier `com.avtanshgupta.onebytwo` for both platforms.

Re-read .github/copilot-instructions.md, .github/shared/invariants.md, the SRS sections §3.4, §5.4, §9.3, §9.4, §11.2, and the design docs at docs/design/03-architecture/deployment-topology.md and docs/design/07-technical/firestore-schema.md before starting. The four invariants apply: single Firebase project, +91 only, INR only, simplifiedBalances server-only-writable.

────────────────────────────────────────
TEAM COMPOSITION FOR THIS PHASE
────────────────────────────────────────

This phase is owned jointly by:
  - devops agent: scripting, secrets, CI wiring, store registration mechanics.
  - architect agent: which services are enabled, regions, rules baseline, App Check policy, billing posture.

The orchestrator sequences them. PM agent reviews the final checklist for SRS coverage. QA agent reviews the readiness checklist before sign-off.

────────────────────────────────────────
WHAT THIS SESSION PRODUCES
────────────────────────────────────────

A. Scripts (executable, idempotent, POSIX-compatible, all under `scripts/firebase/` and `scripts/stores/`).

B. Documentation (under `docs/setup/`).

C. CI wiring updates (under `.github/workflows/` if needed).

D. Updates to existing repo files where the project ID, bundle ID, or application ID was a placeholder.

────────────────────────────────────────
PHASE 1 — DECISIONS AND PRE-FLIGHT
════════════════════════════════════════

Owner: architect.

Produce `docs/setup/00-decisions.md` capturing every project-level decision needed before any setup runs. Each decision must have a chosen value, a rationale, and the SRS or ADR section it implements. At minimum:

  Project ID and display name
  - Firebase project ID (recommendation: `onebytwo-prod`; flag that project IDs are immutable and globally unique).
  - Display name shown in the Firebase Console (recommendation: `One By Two`).
  - Default GCP region for Firestore (recommendation: `asia-south1` Mumbai per SRS §5.2 and design topology).
  - Cloud Storage bucket region (same as Firestore by default).
  - Cloud Functions region (`asia-south1`, hard-coded everywhere).

  App identifiers
  - iOS bundle identifier: `com.avtanshgupta.onebytwo`.
  - Android application ID: `com.avtanshgupta.onebytwo`.
  - URL scheme for deep links: `onebytwo://`.
  - Universal link domain (iOS) and App Link domain (Android): `links.onebytwo.app` (placeholder — flag that DNS will need to point at Firebase Hosting or the marketing site, and AASA / assetlinks.json must be served from there before deep links work end-to-end).

  Auth posture
  - Phone Auth as the ONLY enabled sign-in method per SRS §3.4.
  - SMS region whitelist: India only (block other regions to control SMS costs and abuse).
  - reCAPTCHA Enterprise enabled for Phone Auth abuse prevention.

  App Check posture
  - iOS: DeviceCheck for v1.0; App Attest available as a future upgrade.
  - Android: Play Integrity.
  - Debug tokens: enabled for development only; debug token registration documented.
  - Enforcement targets: Firestore, Storage, Cloud Functions (per SRS §5.4).

  Billing
  - Blaze plan required (Cloud Functions and Phone Auth need it).
  - Budget alert thresholds: 50%, 90%, 100% of a stated monthly cap (recommend ₹5,000 / ~$60 USD for the launch period; flag for stakeholder review).
  - Billing account owner: stakeholder to confirm.

  Observability
  - Crashlytics, Performance Monitoring, Analytics enabled.
  - Default Analytics property linked.
  - BigQuery export for Analytics: deferred to v1.1 unless stakeholder requests now.

  Remote Config keys (initial set, per SRS §9.4 and §4.11)
  - `support_email` — string, default `support@onebytwo.app`.
  - `min_supported_app_version` — string, default `1.0.0`.
  - `feature_flags.simplify_debts_recompute_v2` — boolean, default `false` (kill switch placeholder).

  Service accounts
  - One service account for CI deploys: `github-actions-deployer@<project>.iam.gserviceaccount.com` with explicit roles enumerated.
  - Cloud Functions runtime service account: default, NOT the deployer account (separation of duties).

  Secrets in GitHub
  - Use the secret names from SRS §9.3 verbatim. Do not invent new names.

If the architect cannot decide an item without stakeholder input, mark it `STAKEHOLDER_DECISION` and stop the phase. Do not proceed until I confirm.

────────────────────────────────────────
PHASE 2 — CLI-AUTOMATED SETUP SCRIPTS
════════════════════════════════════════

Owner: devops.

Produce executable, idempotent scripts under `scripts/firebase/`. Each script must:
  - Be POSIX-compatible (`#!/usr/bin/env bash`, `set -euo pipefail`).
  - Print what it is about to do BEFORE doing it.
  - Be safe to re-run (use `firebase --json` queries to check existing state before creating).
  - Read configuration from a single `scripts/firebase/config.env` file (gitignored), with a checked-in `scripts/firebase/config.env.example`.
  - Print a final green checkmark line on success and a clear red error with remediation hints on failure.

Scripts to produce:

2.1  `scripts/firebase/00-prereqs.sh`
     Verifies firebase CLI version, gcloud version, jq, and active login. Errors with install instructions if any are missing.

2.2  `scripts/firebase/01-link-project.sh`
     Sets the active Firebase project, sets `.firebaserc` `default` alias, and confirms billing is on the Blaze plan (errors if not — Blaze must be enabled by hand first).

2.3  `scripts/firebase/02-enable-services.sh`
     Enables required Google Cloud APIs via `gcloud services enable`: firestore.googleapis.com, firebase.googleapis.com, firebaseauth.googleapis.com, firebaseremoteconfig.googleapis.com, firebasestorage.googleapis.com, fcm.googleapis.com, cloudfunctions.googleapis.com, cloudbuild.googleapis.com, secretmanager.googleapis.com, identitytoolkit.googleapis.com, recaptchaenterprise.googleapis.com.

2.4  `scripts/firebase/03-create-firestore.sh`
     Creates the Firestore database in `asia-south1` in Native mode. Idempotent: if it already exists in the right region, no-op. If it exists in a different region, ERROR with a message that this is irreversible and requires a new project.

2.5  `scripts/firebase/04-create-storage.sh`
     Creates the default Cloud Storage bucket in the same region.

2.6  `scripts/firebase/05-deploy-rules-and-indexes.sh`
     Deploys `firestore.rules`, `firestore.indexes.json`, and `storage.rules` from the repo root. Used both for first-time setup and for ongoing rule deploys via CI.

2.7  `scripts/firebase/06-seed-remote-config.sh`
     Uses `firebase remoteconfig:versions:rollback` and `firebase deploy --only remoteconfig` (or the REST API via `gcloud auth print-access-token`) to set the initial Remote Config keys defined in Phase 1. Reads from a checked-in `scripts/firebase/remote-config.template.json`.

2.8  `scripts/firebase/07-register-apps.sh`
     Registers iOS and Android apps with Firebase via `firebase apps:create`:
        iOS: `--bundle-id com.avtanshgupta.onebytwo --display-name "One By Two iOS"`.
        Android: `--package-name com.avtanshgupta.onebytwo --display-name "One By Two Android"`.
     Downloads the resulting `GoogleService-Info.plist` and `google-services.json` to `scripts/firebase/_artifacts/` (gitignored). Prints instructions for moving them to `ios/Runner/` and `android/app/` once the Flutter project exists (i.e., after the skeleton PR).

2.9  `scripts/firebase/08-create-deployer-sa.sh`
     Creates the `github-actions-deployer` service account. Grants the minimum roles needed for CI deploys: Firebase Admin (or narrower if feasible — prefer narrower), Cloud Functions Admin, Firebase Rules Admin, Service Account User. Writes the JSON key to `scripts/firebase/_artifacts/github-actions-deployer.json` and prints clear next-step instructions for uploading it as the `FIREBASE_SERVICE_ACCOUNT_JSON` GitHub secret.

2.10 `scripts/firebase/09-configure-app-check.sh`
     Registers App Check providers (DeviceCheck for iOS, Play Integrity for Android) via the API where supported. The provider keys themselves must be obtained by hand — this script registers what it can and prints the manual steps it cannot do.

2.11 `scripts/firebase/10-smoke-test.sh`
     Runs a smoke test against the production project: writes a doc to a `_setup_smoke` collection from a service-account context, reads it back, deletes it. Confirms Firestore is reachable. Then calls a temporary HTTPS healthcheck URL if one is deployed (skipped before functions exist).

2.12 `scripts/firebase/run-all.sh`
     Top-level orchestrator that runs 00 through 10 in order, with a confirmation prompt before each destructive step. Designed to be re-runnable.

────────────────────────────────────────
PHASE 3 — CONSOLE CHECKLIST (THE HUMAN PART)
════════════════════════════════════════

Owner: devops + architect.

Produce `docs/setup/firebase-console-checklist.md`. This is the human-runnable companion to the scripts. Format every item as a numbered task with:
  - The exact navigation path: `Firebase Console → <Project> → Build → Authentication → Sign-in method`.
  - What to click, what to enter, what to upload.
  - The "done when" assertion (e.g., "the +91 prefix appears in the SMS region whitelist").
  - The SRS or ADR section it implements.

Order matters — earlier steps unlock later ones. Group as follows:

3.1  Pre-Firebase prerequisites
     - Confirm Blaze plan billing is active and a budget is set with the alert thresholds from Phase 1.
     - Confirm the Google account doing the setup has Owner role on the GCP project.

3.2  Authentication
     - Enable Phone provider only.
     - Configure SMS region whitelist to permit only India (ISO country code IN).
     - Enable reCAPTCHA Enterprise for Phone Auth.
     - Add authorised domains for any web preview surfaces (defer if none).

3.3  App Check
     - Register the iOS app with DeviceCheck (paste the Apple key ID and Team ID; download is from App Store Connect — see Phase 4).
     - Register the Android app with Play Integrity (this requires the Play Console app to exist first — flag the dependency).
     - Set Firestore, Storage, and Cloud Functions enforcement to "Enforce" for production traffic and "Allow with monitoring" during the first 48 hours after launch (per launch-readiness in SRS §11.2).
     - Generate one debug token for local development and document where it is stored (1Password / shared vault — not in the repo).

3.4  Cloud Messaging (FCM)
     - Confirm the Firebase Cloud Messaging API (V1) is enabled.
     - For iOS: upload the APNs Authentication Key once it has been created in App Store Connect (Phase 4).
     - For Android: no manual step beyond registering the app.

3.5  Crashlytics
     - Enable Crashlytics for both iOS and Android apps.
     - Confirm dSYM upload setting is "Required" for iOS.

3.6  Analytics
     - Confirm a default Analytics property is linked.
     - Set data-retention to the maximum allowed (14 months).
     - Configure user-property and event filters as documented in `docs/design/07-technical/telemetry-plan.md`.

3.7  Performance Monitoring
     - Enable for both apps.

3.8  Remote Config
     - Verify the keys seeded by `scripts/firebase/06-seed-remote-config.sh` are present.
     - Set the support email default value for production (ask stakeholder for the real address before launch).

3.9  Hosting (deferred but reserved)
     - Reserve the project's default Hosting site for the AASA / assetlinks.json files needed by Universal Links / App Links. Do NOT deploy a marketing site here — that's a separate concern.

3.10 IAM and operational hygiene
     - Confirm the deployer service account exists and has the minimum roles.
     - Confirm there is at least one human Owner (yourself) and document who.
     - Enable two-factor authentication on every Owner account.
     - Review audit logs are enabled (Cloud Audit Logs → all admin reads + writes).

Each item ends with a checkbox: `[ ] Done by <name> on <date>`.

────────────────────────────────────────
PHASE 4 — APP STORE REGISTRATION
════════════════════════════════════════

Owner: devops.

Produce `docs/setup/app-store-registration.md` covering the registration steps that must happen NOW (so the bundle/application IDs are reserved) and that produce credentials Firebase needs.

For Apple App Store Connect:

4.1  Create the app record in App Store Connect with bundle ID `com.avtanshgupta.onebytwo`. Default name "One By Two" — confirm availability.
4.2  Create an APNs Authentication Key (Apple Push). Document key ID, team ID, and the location where the .p8 key is stored (1Password, never the repo). This is what gets uploaded to Firebase in 3.4.
4.3  Create a DeviceCheck key. Document key ID and team ID. This is what gets uploaded to Firebase in 3.3.
4.4  Create an App Store Connect API Key with App Manager role. Download the .p8. The key ID, issuer ID, and base64-encoded .p8 become the GitHub secrets `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_API_KEY_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_BASE64`.
4.5  Set up Fastlane match: create the dedicated private GitHub repo for certificate storage. The match git URL and password become `MATCH_GIT_URL` and `MATCH_PASSWORD`.
4.6  Create the iOS distribution certificate and provisioning profiles via Fastlane match (this can be deferred until just before the first TestFlight upload, but the match repo and credentials must exist now).

For Google Play Console:

4.7  Create the app record in Play Console with application ID `com.avtanshgupta.onebytwo`. Set the default language and the developer contact details.
4.8  Configure the Internal Testing track (closed list initially) — this is where CI uploads land per SRS §9.2.2.
4.9  Generate the Android upload key (keystore). Store the .jks file in 1Password / vault — NEVER the repo. The base64 of this file becomes `ANDROID_KEYSTORE_BASE64`. Keystore password, key alias, and key password become `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
4.10 Create a Google Cloud service account for Play Console uploads. Grant it the "Release manager" role in Play Console. Download the JSON. This becomes `PLAY_SERVICE_ACCOUNT_JSON`.
4.11 Set up Play App Signing (recommended): upload the upload key public certificate; Google will manage the actual signing key.

Each item lists exactly which credential it produces and which GitHub secret name from SRS §9.3 it maps to.

────────────────────────────────────────
PHASE 5 — SECRETS MANIFEST AND GITHUB WIRING
════════════════════════════════════════

Owner: devops.

Produce `docs/setup/secrets-manifest.md`. A single table listing EVERY secret needed in GitHub Actions, with columns:

  | Secret name | Source (where it comes from) | Format | Rotation policy | Used by which workflow |

Every secret name must match SRS §9.3 verbatim. The "Source" column points at the Phase 3 or Phase 4 section that produces the credential.

Then produce `scripts/stores/upload-github-secrets.sh`: a script that uses `gh secret set` to upload secrets from a local `.secrets/` directory (gitignored) into the GitHub repository's Actions secrets. This script reads filenames matching the secret names from the manifest, base64-encodes binary files appropriately, and refuses to run if any secret is missing.

The script must NEVER print secret values to stdout.

────────────────────────────────────────
PHASE 6 — UPDATE EXISTING REPO FILES
════════════════════════════════════════

Owner: devops + architect.

The agentic workspace and design docs were written with placeholders. Now that Phase 1 has chosen real values, update:

6.1  `.firebaserc` — replace placeholder project ID with the chosen `onebytwo-prod` (or whatever Phase 1 chose).
6.2  `.github/workflows/pr.yml` and `.github/workflows/release.yml` — fill in the project ID where the original `# TODO(devops):` markers expected it. Do NOT remove the markers for steps that still legitimately need stakeholder input (e.g., the actual Play Internal Track upload step until the first .aab is built).
6.3  `firebase.json` — confirm emulator port assignments and project default match.
6.4  `docs/setup/README.md` — index of every file in `docs/setup/` plus a one-paragraph summary of the run order: scripts/firebase/run-all.sh → console checklist → app store registration → secrets manifest → upload secrets.

Every change in this phase must reference the Phase 1 decisions doc as the source of truth.

────────────────────────────────────────
PHASE 7 — READINESS CHECKLIST AND HANDOVER
════════════════════════════════════════

Owner: qa (review) + devops (produce).

Produce `docs/setup/readiness-for-skeleton-pr.md`. A short checklist of conditions that must be true before the skeleton bootstrap PR can be opened:

  [ ] Firebase project created, Blaze enabled, billing alerts configured.
  [ ] Firestore exists in `asia-south1`, Native mode.
  [ ] Storage exists, default bucket in same region.
  [ ] Phone Auth enabled, India-only SMS whitelist applied.
  [ ] reCAPTCHA Enterprise enabled.
  [ ] App Check providers registered (debug tokens issued for local dev).
  [ ] iOS and Android apps registered with Firebase, config files downloaded to local artefacts dir.
  [ ] App Store Connect app record exists, APNs key uploaded to Firebase.
  [ ] Play Console app record exists.
  [ ] Deployer service account exists with minimum roles, JSON key downloaded.
  [ ] Initial Remote Config keys seeded.
  [ ] All GitHub secrets from SRS §9.3 uploaded.
  [ ] `.firebaserc` and workflows updated with the real project ID.
  [ ] Smoke test (`scripts/firebase/10-smoke-test.sh`) passes against production.
  [ ] Stakeholder has reviewed budget alerts and named the billing owner.

QA agent reviews this checklist against SRS §11.2 and signs off (text sign-off) before this phase ends.

────────────────────────────────────────
EXECUTION PROTOCOL
────────────────────────────────────────

Phase by phase, stop after each, wait for "proceed". The order is sequential — do not start Phase 2 scripts until Phase 1 decisions are confirmed by the stakeholder, do not start Phase 4 store work until Phase 1 has confirmed bundle IDs, etc.

For any decision that requires me (the stakeholder) — billing cap, contact email, Apple Team ID, etc. — pause and ask explicitly. Do not invent values that look plausible.

For any step requiring credentials — log in to Firebase Console, download a .p8 from Apple, etc. — produce clear instructions and STOP. The agent does not log in to anything; the agent only documents and scripts.

If at any point a Phase 2 script fails when I run it, do not auto-broaden scope to "fix" it. Diagnose, recommend, and let me decide.

────────────────────────────────────────
WHAT THIS SESSION DOES NOT PRODUCE
────────────────────────────────────────

  - No Flutter or Cloud Functions application code.
  - No security rules beyond a default-deny baseline plus the user-doc allow rule (rules grow PR by PR with the features that need them).
  - No actual app icons, splash screens, or store listing assets (separate design/marketing track).
  - No CI workflow rewrites — only filling in the existing placeholders.

Begin with Phase 1, the decisions document.