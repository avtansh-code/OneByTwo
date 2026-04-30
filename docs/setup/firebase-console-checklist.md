# Firebase Console Checklist

Human-runnable companion to the `scripts/firebase/` setup scripts. Every item
that cannot be fully automated by the CLI is documented here with exact
navigation paths and "done when" assertions.

**Order matters** — earlier steps unlock later ones. Complete top-to-bottom.

Source of truth for all values: `docs/setup/00-decisions.md`.

---

## 3.1 Pre-Firebase Prerequisites

### 3.1.1 Confirm Blaze billing

| Field | Value |
|---|---|
| **Navigate** | Firebase Console → Project `onebytwo-avtanshgupta` → ⚙ Settings → Usage and billing → Details & settings |
| **Action** | Verify the billing plan shows **Blaze (pay-as-you-go)**. If it shows Spark, upgrade to Blaze. |
| **Done when** | The billing details page shows "Blaze plan" and a linked billing account. |
| **Reference** | SRS section 3.4; docs/setup/00-decisions.md section 5 |

`[ ] Done by __________ on __________`

### 3.1.2 Configure budget alerts

| Field | Value |
|---|---|
| **Navigate** | Google Cloud Console → Billing → Budgets & alerts → Create budget |
| **Action** | Create a budget for project `onebytwo-avtanshgupta` with a monthly cap of **INR 5,000** (~$60 USD). Add alert thresholds at **50%**, **90%**, and **100%**. Set alert recipients to the billing owner's email. |
| **Done when** | Three alert thresholds appear in the budget details page. |
| **Reference** | docs/setup/00-decisions.md section 5 |

`[ ] Done by __________ on __________`

### 3.1.3 Confirm Owner role

| Field | Value |
|---|---|
| **Navigate** | Google Cloud Console → IAM & Admin → IAM |
| **Action** | Verify your Google account has the **Owner** role on the `onebytwo-avtanshgupta` project. |
| **Done when** | Your account appears with `roles/owner`. |
| **Reference** | Pre-requisite for all subsequent steps |

`[ ] Done by __________ on __________`

---

## 3.2 Authentication

### 3.2.1 Enable Phone provider

| Field | Value |
|---|---|
| **Navigate** | Firebase Console → `onebytwo-avtanshgupta` → Build → Authentication → Sign-in method |
| **Action** | Click **Add new provider** → select **Phone** → toggle **Enable** → Save. Ensure no other sign-in providers are enabled. |
| **Done when** | Phone appears in the provider list with status "Enabled". All other providers show "Disabled". |
| **Reference** | SRS section 3.4 |

`[ ] Done by __________ on __________`

### 3.2.2 Configure SMS region whitelist

| Field | Value |
|---|---|
| **Navigate** | Firebase Console → `onebytwo-avtanshgupta` → Build → Authentication → Settings → SMS Region policy |
| **Action** | Select **Allow only regions on the allow list**. Add **India (IN)** as the sole permitted region. Remove any other regions if present. |
| **Done when** | The SMS region policy shows "Allow" with only the `IN` (India) region listed. |
| **Reference** | SRS section 3.4; docs/setup/00-decisions.md section 3 |

`[ ] Done by __________ on __________`

### 3.2.3 Enable reCAPTCHA Enterprise

| Field | Value |
|---|---|
| **Navigate** | Firebase Console → `onebytwo-avtanshgupta` → Build → Authentication → Settings → reCAPTCHA Enterprise |
| **Action** | Toggle **reCAPTCHA Enterprise** to enabled. Accept the terms if prompted. This provides bot protection for Phone Auth flows. |
| **Done when** | reCAPTCHA Enterprise shows as "Enabled" in the Authentication settings. |
| **Reference** | SRS section 5.4; docs/setup/00-decisions.md section 3 |

`[ ] Done by __________ on __________`

### 3.2.4 Authorised domains

| Field | Value |
|---|---|
| **Navigate** | Firebase Console → `onebytwo-avtanshgupta` → Build → Authentication → Settings → Authorised domains |
| **Action** | No action required for v1.0 (mobile-only). If a web preview surface is added later, its domain must be added here. Confirm only default domains (`localhost`, `onebytwo-avtanshgupta.firebaseapp.com`, `onebytwo-avtanshgupta.web.app`) are listed. |
| **Done when** | Only default Firebase domains are present. |
| **Reference** | N/A (defensive check) |

`[ ] Done by __________ on __________`

---

## 3.3 App Check

### 3.3.1 Register iOS with DeviceCheck

| Field | Value |
|---|---|
| **Navigate** | Firebase Console → `onebytwo-avtanshgupta` → App Check → Apps → One By Two iOS |
| **Action** | Select **DeviceCheck** as the attestation provider. Enter: **Apple Team ID:** `S6ULATL6PT`. **Key ID:** (from App Store Connect — see Phase 4 section 4.3). Upload the DeviceCheck private key (.p8) obtained from App Store Connect. |
| **Done when** | The iOS app shows DeviceCheck as the registered provider with a green status. |
| **Reference** | SRS section 5.4; docs/setup/00-decisions.md section 4 |

**Dependency:** Requires the DeviceCheck key from Phase 4 (section 4.3).

`[ ] Done by __________ on __________`

### 3.3.2 Register Android with Play Integrity

| Field | Value |
|---|---|
| **Navigate** | Firebase Console → `onebytwo-avtanshgupta` → App Check → Apps → One By Two Android |
| **Action** | Select **Play Integrity** as the attestation provider. Play Integrity should auto-configure once the app exists in Play Console. |
| **Done when** | The Android app shows Play Integrity as the registered provider. |
| **Reference** | SRS section 5.4; docs/setup/00-decisions.md section 4 |

**Dependency:** Requires the Play Console app record from Phase 4 (section 4.7).

`[ ] Done by __________ on __________`

### 3.3.3 Set enforcement policy

| Field | Value |
|---|---|
| **Navigate** | Firebase Console → `onebytwo-avtanshgupta` → App Check → APIs |
| **Action** | For each of **Cloud Firestore**, **Cloud Storage**, and **Cloud Functions**: set enforcement to **"Allow with monitoring"** initially. Switch to **"Enforce"** 48 hours after launch. |
| **Done when** | All three APIs show "Allow with monitoring" (pre-launch) or "Enforced" (post-launch). |
| **Reference** | SRS section 11.2; docs/setup/00-decisions.md section 4 |

`[ ] Done by __________ on __________`

### 3.3.4 Generate debug token

| Field | Value |
|---|---|
| **Navigate** | Firebase Console → `onebytwo-avtanshgupta` → App Check → Apps → (select app) → overflow menu → Manage debug tokens |
| **Action** | Click **Add debug token**. Name it descriptively (e.g., `local-dev-<your-name>`). Copy the generated token. |
| **Done when** | At least one debug token appears in the list. The token value is stored in 1Password (team vault), NEVER in the repository. |
| **Reference** | docs/setup/00-decisions.md section 4 |

`[ ] Done by __________ on __________`

---

## 3.4 Cloud Messaging (FCM)

### 3.4.1 Verify FCM V1 API

| Field | Value |
|---|---|
| **Navigate** | Firebase Console → `onebytwo-avtanshgupta` → Project settings → Cloud Messaging |
| **Action** | Verify **Firebase Cloud Messaging API (V1)** is shown as "Enabled". If it shows "Disabled", click the three-dot menu and enable it. The legacy API should remain disabled. |
| **Done when** | "Firebase Cloud Messaging API (V1)" shows "Enabled". |
| **Reference** | SRS section 4.10 |

`[ ] Done by __________ on __________`

### 3.4.2 Upload APNs Authentication Key (iOS)

| Field | Value |
|---|---|
| **Navigate** | Firebase Console → `onebytwo-avtanshgupta` → Project settings → Cloud Messaging → Apple app configuration |
| **Action** | Click **Upload** under APNs Authentication Key. Upload the `.p8` APNs key file obtained from App Store Connect (Phase 4 section 4.2). Enter the **Key ID** and **Team ID** (`S6ULATL6PT`). |
| **Done when** | The APNs Authentication Key section shows the uploaded key with correct Key ID and Team ID. |
| **Reference** | SRS section 4.10 |

**Dependency:** Requires the APNs key from Phase 4 (section 4.2).

`[ ] Done by __________ on __________`

### 3.4.3 Android FCM — no manual step

No manual action required for Android. FCM is automatically configured when the Android app is registered with Firebase.

`[x] No action required`

---

## 3.5 Crashlytics

### 3.5.1 Enable Crashlytics

| Field | Value |
|---|---|
| **Navigate** | Firebase Console → `onebytwo-avtanshgupta` → Release & Monitor → Crashlytics |
| **Action** | Select each app (iOS and Android) and complete the Crashlytics onboarding flow. Crashlytics will show "Waiting for your first crash report" until the app sends data. |
| **Done when** | Crashlytics dashboard loads for both iOS and Android apps (even if showing "waiting for data"). |
| **Reference** | SRS section 5.4; docs/setup/00-decisions.md section 6 |

`[ ] Done by __________ on __________`

### 3.5.2 Confirm dSYM upload setting (iOS)

| Field | Value |
|---|---|
| **Navigate** | Firebase Console → `onebytwo-avtanshgupta` → Project settings → Integrations → Crashlytics (or within the Crashlytics dashboard settings) |
| **Action** | Verify that dSYM upload is configured. In the iOS build pipeline, dSYMs will be uploaded automatically via the `firebase_crashlytics` Flutter package's build phase script. No manual console action is needed beyond enabling Crashlytics, but confirm the setting is visible. |
| **Done when** | The Crashlytics settings page does not show any warnings about missing dSYMs. |
| **Reference** | SRS section 5.4 |

`[ ] Done by __________ on __________`

---

## 3.6 Analytics

### 3.6.1 Confirm default Analytics property

| Field | Value |
|---|---|
| **Navigate** | Firebase Console → `onebytwo-avtanshgupta` → Analytics → Dashboard |
| **Action** | Verify a default Google Analytics property is linked to the project. If not linked, click **Enable Google Analytics** and follow the setup flow. Select the default account or create a new one. |
| **Done when** | The Analytics dashboard loads and shows a linked property. |
| **Reference** | docs/setup/00-decisions.md section 6 |

`[ ] Done by __________ on __________`

### 3.6.2 Set data retention to 14 months

| Field | Value |
|---|---|
| **Navigate** | Google Analytics Console → Admin → Data Settings → Data Retention |
| **Action** | Set **Event data retention** to **14 months** (the maximum). Toggle **Reset user data on new activity** to ON. |
| **Done when** | Data retention shows "14 months" with reset on new activity enabled. |
| **Reference** | docs/setup/00-decisions.md section 6 |

`[ ] Done by __________ on __________`

### 3.6.3 Register custom dimensions

| Field | Value |
|---|---|
| **Navigate** | Google Analytics Console → Admin → Custom Definitions → Custom Dimensions |
| **Action** | Register the following event-scoped custom dimensions (from `docs/design/07-technical/telemetry-plan.md`): `context_type`, `split_method`, `category`, `source`, `method`, `amount_range`, `screen`, `error_type`. |
| **Done when** | All listed custom dimensions appear in the Custom Dimensions list. |
| **Reference** | docs/design/07-technical/telemetry-plan.md section 4.3 |

`[ ] Done by __________ on __________`

---

## 3.7 Performance Monitoring

### 3.7.1 Enable Performance Monitoring

| Field | Value |
|---|---|
| **Navigate** | Firebase Console → `onebytwo-avtanshgupta` → Release & Monitor → Performance |
| **Action** | Complete the Performance Monitoring onboarding for both iOS and Android apps. The SDK integration happens in code; here we just ensure the console side is ready. |
| **Done when** | Performance dashboard loads for both apps (even if showing "waiting for data"). |
| **Reference** | docs/setup/00-decisions.md section 6 |

`[ ] Done by __________ on __________`

---

## 3.8 Remote Config

### 3.8.1 Verify seeded keys

| Field | Value |
|---|---|
| **Navigate** | Firebase Console → `onebytwo-avtanshgupta` → Engage → Remote Config |
| **Action** | Verify the following keys exist with correct default values (seeded by `scripts/firebase/06-seed-remote-config.sh` on 2026-05-01): |

| Key | Expected Default |
|---|---|
| `support_email` | `support@onebytwo.app` |
| `min_supported_app_version` | `1.0.0` |
| `feature_flags.simplify_debts_recompute_v2` | `false` |

| Field | Value |
|---|---|
| **Done when** | All three keys appear in Remote Config with the expected defaults. |
| **Reference** | SRS section 9.4; docs/setup/00-decisions.md section 7 |

`[ ] Done by __________ on __________`

### 3.8.2 Confirm support email for production

| Field | Value |
|---|---|
| **Navigate** | Firebase Console → Remote Config → `support_email` |
| **Action** | Before GA launch, update the default value to the real production support email address (confirm with stakeholder). The placeholder `support@onebytwo.app` is sufficient for development. |
| **Done when** | The support email value matches the stakeholder-confirmed production address. |
| **Reference** | SRS section 3.5 |

`[ ] Done by __________ on __________`

---

## 3.9 Hosting (Deferred but Reserved)

### 3.9.1 Reserve default Hosting site

| Field | Value |
|---|---|
| **Navigate** | Firebase Console → `onebytwo-avtanshgupta` → Build → Hosting |
| **Action** | Complete the Hosting setup wizard to reserve the default site (`onebytwo-avtanshgupta.web.app`). Do NOT deploy any content — this site will serve only the `apple-app-site-association` and `assetlinks.json` files for Universal Links / App Links when the deep-link feature is implemented. |
| **Done when** | The Hosting dashboard shows the default site as created. No deploy is needed. |
| **Reference** | docs/setup/00-decisions.md section 2 (deep link domains) |

`[ ] Done by __________ on __________`

---

## 3.10 IAM and Operational Hygiene

### 3.10.1 Confirm deployer service account

| Field | Value |
|---|---|
| **Navigate** | Google Cloud Console → IAM & Admin → Service Accounts |
| **Action** | Verify `github-actions-deployer@onebytwo-avtanshgupta.iam.gserviceaccount.com` exists and has the following roles: `roles/firebase.admin`, `roles/cloudfunctions.admin`, `roles/firebaserules.admin`, `roles/iam.serviceAccountUser`. |
| **Done when** | The service account appears with all four roles visible in IAM. |
| **Reference** | docs/setup/00-decisions.md section 8 |

`[ ] Done by __________ on __________`

### 3.10.2 Confirm human Owner

| Field | Value |
|---|---|
| **Navigate** | Google Cloud Console → IAM & Admin → IAM |
| **Action** | Confirm at least one human account (avtanshgupta) has the Owner role. Document the Owner in the table below. |
| **Done when** | At least one human Owner is confirmed and documented. |
| **Reference** | Operational hygiene |

**Owner:** avtanshgupta

`[ ] Done by __________ on __________`

### 3.10.3 Enable two-factor authentication

| Field | Value |
|---|---|
| **Navigate** | Google Account → Security → 2-Step Verification |
| **Action** | Ensure 2FA is enabled on every Google account with Owner access to the `onebytwo-avtanshgupta` project. |
| **Done when** | 2-Step Verification shows as "On" for all Owner accounts. |
| **Reference** | Operational hygiene |

`[ ] Done by __________ on __________`

### 3.10.4 Review audit logs

| Field | Value |
|---|---|
| **Navigate** | Google Cloud Console → IAM & Admin → Audit Logs |
| **Action** | Verify that **Admin Read** and **Admin Write** audit logs are enabled for all services. Data Read and Data Write are optional but recommended for Firestore. |
| **Done when** | Admin Read and Admin Write columns show enabled (checkmark) for all listed services. |
| **Reference** | Operational hygiene |

`[ ] Done by __________ on __________`
