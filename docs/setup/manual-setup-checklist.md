# Manual Setup Checklist

Remaining tasks that require human interaction with the Firebase Console, Apple
Developer Portal, Google Play Console, or local CLI. Ordered by dependency —
complete top-to-bottom.

Source of truth for all values: `docs/setup/00-decisions.md`.

---

## Block 1 — Firebase Console (no external dependencies)

These tasks can be done immediately in the Firebase Console.

### 1.1 Configure budget alerts

- **Where:** [Google Cloud Console → Billing → Budgets & alerts](https://console.cloud.google.com/billing/)
- **Steps:**
  1. Click **Create budget**.
  2. Select project `onebytwo-avtanshgupta`.
  3. Set **Target amount** to `INR 5,000` per month.
  4. Add three alert thresholds: `50%`, `90%`, `100%`.
  5. Set alert recipients to your billing email.
  6. Click **Finish**.
- **Expected result:** Three thresholds appear in the budget details page. You
  receive a confirmation email about the new budget.

[x] Done

---

### 1.2 Enable Phone Auth

- **Where:** [Firebase Console → Authentication → Sign-in method](https://console.firebase.google.com/project/onebytwo-avtanshgupta/authentication/providers)
- **Steps:**
  1. Click **Add new provider**.
  2. Select **Phone**.
  3. Toggle **Enable** to on.
  4. Click **Save**.
  5. Verify no other providers are enabled (Email, Google, etc. should all be disabled).
- **Expected result:** Phone appears in the provider list with status "Enabled".
  All other providers show "Disabled".

[x] Done

---

### 1.3 Set SMS region whitelist to India only

- **Where:** [Firebase Console → Authentication → Settings](https://console.firebase.google.com/project/onebytwo-avtanshgupta/authentication/settings)
- **Steps:**
  1. Scroll to **SMS Region policy**.
  2. Select **Allow only regions on the allow list**.
  3. Click **Add region** → type `India` → select `India (IN)`.
  4. Remove any other regions if present.
  5. Click **Save**.
- **Expected result:** The SMS region policy shows "Allow" with only `IN`
  (India) listed.

[x] Done

---

### 1.4 Enable reCAPTCHA Enterprise

- **Where:** [Firebase Console → Authentication → Settings](https://console.firebase.google.com/project/onebytwo-avtanshgupta/authentication/settings)
- **Steps:**
  1. Scroll to **reCAPTCHA Enterprise**.
  2. Toggle to **Enabled**.
  3. Accept the terms if prompted.
- **Expected result:** reCAPTCHA Enterprise shows as "Enabled".

[x] Done

---

### 1.5 Enable Crashlytics

- **Where:** [Firebase Console → Crashlytics](https://console.firebase.google.com/project/onebytwo-avtanshgupta/crashlytics)
- **Steps:**
  1. Select the **One By Two iOS** app from the app selector.
  2. Complete the Crashlytics onboarding wizard (it will show "Waiting for your
     first crash report" — this is expected before app code exists).
  3. Repeat for the **One By Two Android** app.
- **Expected result:** The Crashlytics dashboard loads for both apps, showing
  "Waiting for your first crash report".

[x] Done

---

### 1.6 Link Analytics property and set data retention

- **Where:** [Firebase Console → Analytics](https://console.firebase.google.com/project/onebytwo-avtanshgupta/analytics)
- **Steps:**
  1. If Analytics is not yet enabled, click **Enable Google Analytics** and
     follow the setup flow. Select the default Google Analytics account.
  2. Once linked, go to [Google Analytics Admin → Data Settings → Data Retention](https://analytics.google.com/).
  3. Set **Event data retention** to **14 months**.
  4. Toggle **Reset user data on new activity** to **On**.
  5. Click **Save**.
- **Expected result:** Analytics dashboard loads in Firebase. Data retention
  shows "14 months" in the Google Analytics admin.

[x] Done

---

### 1.7 Register custom dimensions in Analytics

- **Where:** [Google Analytics Console](https://analytics.google.com/) → select the `OneByTwo` property → Admin (gear icon, bottom-left) → under **Data display** → **Custom definitions**
- **Steps:**
  1. Click the **Custom dimensions** tab.
  2. Click **Create custom dimension**.
  3. Fill in the form for each dimension listed below, then click **Save** and repeat:

     | Dimension name | Scope | Event parameter | Description |
     |---|---|---|---|
     | `context_type` | **Event** | `context_type` | Whether the action is in a friendship or group context |
     | `split_method` | **Event** | `split_method` | How the expense was split (equal, unequal, percentage, shares) |
     | `category` | **Event** | `category` | Expense category (food, transport, etc.) |
     | `source` | **Event** | `source` | Where the user came from (skip, get_started, etc.) |
     | `method` | **Event** | `method` | Auth or action method (phone, contacts, manual, invite) |
     | `amount_range` | **Event** | `amount_range` | Bucketed expense amount (under_500, 500_5000, etc.) |
     | `screen` | **Event** | `screen` | Screen where the event occurred |
     | `error_type` | **Event** | `error_type` | Type of error shown to the user |

  4. For each row:
     - **Dimension name:** use the value from the first column (e.g., `context_type`).
     - **Scope:** select **Event** from the dropdown.
     - **Description:** use the text from the Description column.
     - **Event parameter:** enter the exact same string as the Dimension name (e.g., `context_type`). This links the dimension to the parameter your app code sends with `FirebaseAnalytics.logEvent()`.
     - Click **Save**.
- **Expected result:** All 8 custom dimensions appear in the Custom dimensions
  list with scope "Event" and status "Active".

[x] Done

---

### 1.8 Enable Performance Monitoring

- **Where:** [Firebase Console → Performance](https://console.firebase.google.com/project/onebytwo-avtanshgupta/performance)
- **Steps:**
  1. Complete the Performance Monitoring onboarding for both iOS and Android apps.
- **Expected result:** Performance dashboard loads for both apps (showing
  "Waiting for data").

[x] Done

---

### 1.9 Verify Remote Config keys

- **Where:** [Firebase Console → Remote Config](https://console.firebase.google.com/project/onebytwo-avtanshgupta/config)
- **Steps:**
  1. Verify the following keys exist with correct defaults:

     | Key | Expected Default |
     |---|---|
     | `support_email` | `support@onebytwo.app` |
     | `min_supported_app_version` | `1.0.0` |
     | `feature_flags.simplify_debts_recompute_v2` | `false` |

- **Expected result:** All three keys are present with the values shown above.

[x] Done

---

### 1.10 Reserve Firebase Hosting site

- **Where:** [Firebase Console → Hosting](https://console.firebase.google.com/project/onebytwo-avtanshgupta/hosting)
- **Steps:**
  1. Click **Get Started**.
  2. Follow the setup wizard (you do not need to deploy anything).
  3. The default site `onebytwo-avtanshgupta.web.app` will be reserved.
- **Expected result:** The Hosting dashboard shows the default site as created.
  No content is deployed — this site will serve AASA / assetlinks.json later.

[x] Done

---

### 1.11 Verify FCM V1 API is enabled

- **Where:** [Firebase Console → Project Settings → Cloud Messaging](https://console.firebase.google.com/project/onebytwo-avtanshgupta/settings/cloudmessaging)
- **Steps:**
  1. Verify **Firebase Cloud Messaging API (V1)** shows "Enabled".
  2. If disabled, click the three-dot menu and enable it.
  3. The legacy FCM API should remain disabled.
- **Expected result:** "Firebase Cloud Messaging API (V1)" shows "Enabled".

[x] Done

---

### 1.12 Verify deployer service account roles and enable 2FA

- **Where:** [Google Cloud Console → IAM](https://console.cloud.google.com/iam-admin/iam?project=onebytwo-avtanshgupta)
- **Steps:**
  1. Find `github-actions-deployer@onebytwo-avtanshgupta.iam.gserviceaccount.com`.
  2. Verify it has these roles: `Firebase Admin`, `Cloud Functions Admin`,
     `Firebase Rules Admin`, `Service Account User`.
  3. Verify your own account (`avtanshgupta`) has the **Owner** role.
  4. Go to [Google Account → Security → 2-Step Verification](https://myaccount.google.com/security)
     and confirm 2FA is enabled on every Owner account.
  5. Go to [Cloud Audit Logs](https://console.cloud.google.com/iam-admin/audit?project=onebytwo-avtanshgupta)
     and verify **Admin Read** and **Admin Write** are enabled.
- **Expected result:** SA has all 4 roles. Owner account has 2FA. Audit logs
  are enabled.

[x] Done

---

## Block 2 — Apple Developer Portal (unlocks Block 3)

### 2.1 Register Bundle ID

- **Where:** [Apple Developer → Certificates, Identifiers & Profiles → Identifiers](https://developer.apple.com/account/resources/identifiers/list)
- **Steps:**
  1. Click **+** to register a new identifier.
  2. Select **App IDs** → **App**.
  3. Enter description: `One By Two`.
  4. Select **Explicit** and enter Bundle ID: `com.avtanshgupta.onebytwo`.
  5. Under Capabilities, enable **Push Notifications** and **Associated Domains**.
  6. Click **Continue** → **Register**.
- **Expected result:** `com.avtanshgupta.onebytwo` appears in the Identifiers list.

[x] Done

---

### 2.2 Create App Store Connect app record

- **Where:** [App Store Connect → My Apps](https://appstoreconnect.apple.com/apps)
- **Steps:**
  1. Click **+** → **New App**.
  2. Platform: **iOS**.
  3. Name: `One By Two`.
  4. Primary language: **English (U.K.)**.
  5. Bundle ID: select `com.avtanshgupta.onebytwo` (registered in step 2.1).
  6. SKU: `onebytwo-ios-v1`.
  7. User access: **Full Access**.
  8. Click **Create**.
- **Expected result:** The app appears in My Apps with status
  "Prepare for Submission".

[x] Done

---

### 2.3 Create APNs Authentication Key

- **Where:** [Apple Developer → Certificates, Identifiers & Profiles → Keys](https://developer.apple.com/account/resources/authkeys/list)
- **Steps:**
  1. Click **+** to create a new key.
  2. Key name: `One By Two APNs`.
  3. Check **Apple Push Notifications service (APNs)**.
  4. Click **Continue** → **Register**.
  5. **Download** the `.p8` file. This can only be downloaded once.
  6. Note the **Key ID** shown on the confirmation page.
- **Expected result:** A `.p8` file is downloaded. Key ID is noted.
- **Store:** `.p8` file + Key ID → 1Password (team vault). NEVER in the repo.

| Credential | Where it goes next |
|---|---|
| `.p8` file | Firebase Console (step 3.1 — FCM APNs config) |
| Key ID | Firebase Console (step 3.1) |
| Team ID | `S6ULATL6PT` (already known) |

[x] Done

---

### 2.4 Create DeviceCheck Key

- **Where:** [Apple Developer → Certificates, Identifiers & Profiles → Keys](https://developer.apple.com/account/resources/authkeys/list)
- **Steps:**
  1. Click **+** to create a new key.
  2. Key name: `One By Two DeviceCheck`.
  3. Check **DeviceCheck**.
  4. Click **Continue** → **Register**.
  5. **Download** the `.p8` file.
  6. Note the **Key ID**.
- **Expected result:** A `.p8` file is downloaded. Key ID is noted.
- **Store:** `.p8` file + Key ID → 1Password. NEVER in the repo.
- **Note:** Apple allows max 2 keys. If you already have 2, reuse one key with
  both APNs and DeviceCheck enabled (combine steps 2.3 and 2.4).

| Credential | Where it goes next |
|---|---|
| `.p8` file | Firebase Console (step 3.2 — App Check iOS) |
| Key ID | Firebase Console (step 3.2) |

[x] Done

---

### 2.5 Create App Store Connect API Key

- **Where:** [App Store Connect → Users and Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api)
- **Steps:**
  1. Click **+** under Keys to generate a new key.
  2. Name: `One By Two CI`.
  3. Access: **App Manager**.
  4. Click **Generate**.
  5. **Download** the `.p8` API key file. This can only be downloaded once.
  6. Note the **Key ID** shown in the table.
  7. Note the **Issuer ID** shown at the top of the Keys page.
  8. Base64-encode the `.p8`: `base64 -i AuthKey_XXXXXXXX.p8 > key_base64.txt`
- **Expected result:** API key appears in the list with status "Active".
- **Store:** Raw `.p8` → 1Password.

| Credential | GitHub Secret Name |
|---|---|
| Key ID | `APP_STORE_CONNECT_API_KEY_ID` |
| Issuer ID | `ISSUER_ID` |
| Base64-encoded `.p8` | `KEY_BASE64` |

[x] Done

---

### 2.6 Create Fastlane match repository

Fastlane match is a tool that stores your iOS signing certificates and
provisioning profiles in a private Git repository, encrypted with a passphrase.
This lets CI (GitHub Actions) sign iOS builds without you manually exporting
certificates. The repo holds only encrypted blobs — never readable certs.

- **Where:** [GitHub → New Repository](https://github.com/new)
- **Steps:**
  1. Go to [github.com/new](https://github.com/new).
  2. **Repository name:** `onebytwo-match-certs`
  3. **Owner:** `avtansh-code`
  4. **Visibility:** select **Private** (this repo must never be public).
  5. **Do NOT** tick "Add a README file" — the repo must be completely empty.
  6. Click **Create repository**.
  7. Choose a strong passphrase (e.g., run `openssl rand -base64 24` in your
     terminal to generate one). This passphrase encrypts/decrypts the
     certificates stored in the repo.
  8. Save the passphrase somewhere safe (Keychain, Passwords app, or a secure
     note on your device). You will need it every time CI runs.
- **Expected result:** An empty private repo exists at
  `github.com/avtansh-code/onebytwo-match-certs`. You have the passphrase saved.
- **Note:** You do NOT need to run `fastlane match` now. That happens later
  during the skeleton Flutter PR when Fastlane is configured. This step just
  creates the empty repo and passphrase so the credentials are ready.

| Credential | GitHub Secret Name |
|---|---|
| Repo URL | `MATCH_GIT_URL` (`https://github.com/avtansh-code/onebytwo-match-certs.git`) |
| Passphrase | `MATCH_PASSWORD` |

[x] Done

---

## Block 3 — Firebase Console (requires Apple keys from Block 2)

### 3.1 Upload APNs key to Firebase

- **Where:** [Firebase Console → Project Settings → Cloud Messaging](https://console.firebase.google.com/project/onebytwo-avtanshgupta/settings/cloudmessaging)
- **Steps:**
  1. Scroll to **Apple app configuration**.
  2. Click **Upload** under APNs Authentication Key.
  3. Upload the `.p8` file from step 2.3.
  4. Enter the **Key ID** from step 2.3.
  5. Enter **Team ID**: `S6ULATL6PT`.
  6. Click **Upload**.
- **Expected result:** The APNs Authentication Key section shows the uploaded
  key with correct Key ID and Team ID.

[x] Done

---

### 3.2 Register iOS DeviceCheck in App Check

- **Where:** [Firebase Console → App Check](https://console.firebase.google.com/project/onebytwo-avtanshgupta/appcheck)
- **Steps:**
  1. Click on the **One By Two iOS** app (bundle `com.avtanshgupta.onebytwo`).
  2. Select **DeviceCheck** as the attestation provider.
  3. Upload the DeviceCheck `.p8` key from step 2.4.
  4. Enter the **Key ID** from step 2.4.
  5. Enter **Team ID**: `S6ULATL6PT`.
  6. Click **Save**.
- **Expected result:** The iOS app shows DeviceCheck as the registered provider
  with a green checkmark.

[x] Done

---

## Block 4 — Google Play Console

**Account type note:** These steps are written for a **personal (individual)**
Google Play developer account. Some features (like API access) require identity
verification to be complete first.

### 4.1 Create Play Console app record

- **Where:** [Google Play Console](https://play.google.com/console/) → **All apps**
- **Steps:**
  1. Click **Create app** (top-right, or on the All Apps page).
  2. Fill in the form:
     - **App name:** `One By Two`
     - **Default language:** English (United Kingdom)
     - **App or game:** App
     - **Free or paid:** Free
  3. Check the **Declarations** boxes:
     - Developer Program Policies
     - US export laws
  4. Click **Create app** at the bottom-right.
  5. You will land on the app **Dashboard** showing a list of setup tasks.
  6. Go to the **Dashboard** setup checklist and fill in the required items:
     - **Store listing → Main store listing:** add a temporary app description
       (you can update this later with real copy and screenshots).
     - **App content:** fill in the privacy policy URL, ads declaration,
       content rating questionnaire, target audience, and data safety form
       as prompted. These are required before you can create any release.
     - **Store settings:** set app category (Finance) and contact details
       (use `support@onebytwo.app`).
- **Expected result:** The app appears in the All Apps list. The Dashboard
  shows your setup progress.

[x] Done

---

### 4.2 Set up internal testing testers list

- **Where:** Play Console → `One By Two` → left sidebar → **Testing** → **Internal testing**
- **Steps:**
  1. Click the **Testers** tab (not "Releases").
  2. Click **Create email list**.
  3. List name: `Internal Testers`.
  4. Add your Google account email as the first tester.
  5. Click **Save changes**.
- **Expected result:** A tester list named "Internal Testers" exists with at
  least one email address.
- **Note:** You cannot create a release or start a rollout until you upload an
  `.aab` file. That happens later from CI. For now, just set up the testers list.

[x] Done

---

### 4.3 Generate Android upload keystore

- **Where:** Your local terminal
- **Steps:**
  1. Run:
     ```bash
     keytool -genkey -v \
       -keystore onebytwo-upload.jks \
       -keyalg RSA -keysize 2048 \
       -validity 10000 \
       -alias onebytwo-upload
     ```
  2. Enter a strong password for the keystore when prompted.
  3. Enter a strong password for the key when prompted (can be the same).
  4. Fill in the certificate fields (CN, OU, O, L, ST, C) with your details.
  5. Confirm with `yes`.
  6. Store the `.jks` file securely (Keychain / secure folder). NEVER commit it.
  7. Base64-encode for the GitHub secret:
     ```bash
     base64 -i onebytwo-upload.jks > keystore_base64.txt
     ```
- **Expected result:** `onebytwo-upload.jks` file exists locally.

| Credential | GitHub Secret Name |
|---|---|
| Base64-encoded `.jks` | `ANDROID_KEYSTORE_BASE64` |
| Keystore password | `ANDROID_KEYSTORE_PASSWORD` |
| Key alias | `KEY_ALIAS` (value: `onebytwo-upload`) |
| Key password | `KEY_PASSWORD` |

[x] Done

---

### 4.4 Set up Play App Signing

Play App Signing must be configured before your first upload. Google manages the
actual signing key; you keep the upload key for CI.

- **Where:** Play Console → `One By Two` → left sidebar → **Release** →
  **App signing** (or **Policy and programs** → **App integrity** →
  **Play App Signing** tab — the exact location varies by console version)
- **Steps:**
  1. If you see a "Set up app signing" prompt, click it.
  2. Select **Use a Java keystore** (or "Upload a key exported from Java
     keystore").
  3. On your local terminal, extract the upload certificate from your keystore:
     ```bash
     keytool -export -rfc \
       -keystore onebytwo-upload.jks \
       -alias onebytwo-upload \
       -file upload-cert.pem
     ```
     Enter the keystore password when prompted.
  4. Back in the Play Console, upload `upload-cert.pem`.
  5. Click **Save** (or **Continue** / **Confirm**).
- **Expected result:** The page shows **"App signing by Google Play is
  enabled"** with two certificates displayed:
  - **App signing key certificate** (managed by Google)
  - **Upload key certificate** (your keystore — the SHA-256 fingerprint should
    match your local keystore)
- **Note:** If the console says app signing will be configured on your first
  upload, that is fine — proceed and it will activate when CI uploads the first
  `.aab`.

[x] Done

---

### 4.5 Create Play Console service account (for CI uploads)

The dedicated "API Access" page has been retired from Google Play Console. You
now manage service accounts via **Google Cloud Console** and grant access via
**Users and permissions** in Play Console.

- **Steps (Google Cloud Console — enable API):**
  1. Go to [Google Cloud Console → APIs & Services → Library](https://console.cloud.google.com/apis/library?project=onebytwo-avtanshgupta).
  2. Search for **Google Play Android Developer API**.
  3. Click on it → click **Enable** (if already enabled, you'll see "Manage").

- **Steps (Google Cloud Console — create service account):**
  4. Go to [IAM & Admin → Service Accounts](https://console.cloud.google.com/iam-admin/serviceaccounts?project=onebytwo-avtanshgupta).
  5. Click **+ Create Service Account**.
  6. Service account name: `play-store-uploader`.
  7. Skip the "Grant access" step (no GCP roles needed).
  8. Click **Done**.
  9. In the service accounts list, click on `play-store-uploader`.
  10. **Copy the service account email** (it will look like
      `play-store-uploader@onebytwo-avtanshgupta.iam.gserviceaccount.com`).
  11. Go to the **Keys** tab → **Add Key** → **Create new key** → select
      **JSON** → click **Create**.
  12. A `.json` file downloads automatically. Store it securely.

- **Steps (Play Console — invite service account):**
  13. Go to [Google Play Console → Users and permissions](https://play.google.com/console/developers/6893399599599209052/users-and-permissions).
  14. Click **Invite new users**.
  15. In the **Email address** field, paste the service account email you
      copied in step 10.
  16. Under **Account permissions**, check:
      - **View app information and download bulk reports** (under View)
      - **Create, edit, and delete draft releases** (under Release)
      - **Release to production, exclude devices, and use Play App Signing** (under Release)
      - **Manage testing tracks and edit tester lists** (under Release)
  17. Under **App permissions**, click **Add app** → select `One By Two` →
      apply the same release permissions listed above.
  18. Click **Invite user** → confirm.
  19. The invitation is accepted automatically for service accounts (no email
      confirmation needed).
- **Expected result:** The service account appears in the Users and permissions
  list with the granted permissions.

| Credential | GitHub Secret Name |
|---|---|
| JSON key file | `PLAY_SERVICE_ACCOUNT_JSON` |

[x] Done

---

### 4.6 Register Android Play Integrity in App Check

- **Where:** [Firebase Console → App Check](https://console.firebase.google.com/project/onebytwo-avtanshgupta/appcheck)
- **Pre-requisite:** You need the **SHA-256 fingerprint** of your upload
  keystore (created in step 4.3).
- **Steps:**
  1. First, get your SHA-256 fingerprint. Run in your terminal:
     ```bash
     keytool -list -v \
       -keystore onebytwo-upload.jks \
       -alias onebytwo-upload
     ```
     Enter the keystore password. Look for the line:
     ```
     SHA256: XX:XX:XX:XX:...
     ```
     Copy the full SHA-256 fingerprint.
  2. Go to [Firebase Console → Project Settings → General](https://console.firebase.google.com/project/onebytwo-avtanshgupta/settings/general).
  3. Scroll down to **Your apps** → find the **One By Two Android** app.
  4. Under **SHA certificate fingerprints**, click **Add fingerprint**.
  5. Paste the SHA-256 fingerprint (with or without colons — Firebase accepts
     both formats).
  6. Click **Save**.
  7. Now go to [Firebase Console → App Check](https://console.firebase.google.com/project/onebytwo-avtanshgupta/appcheck).
  8. Click on the **One By Two Android** app (`com.avtanshgupta.onebytwo`).
  9. Select **Play Integrity** as the attestation provider.
  10. The SHA-256 you registered in step 5 will be used for verification.
  11. Leave the default token TTL (1 hour).
  12. Click **Save**.
- **Expected result:** The Android app shows Play Integrity as the registered
  provider with a green status.
- **Note:** Play Integrity attestation only works on real devices with Google
  Play Services. During local development, use App Check debug tokens instead
  (Block 5, step 5.2). If you also set up Play App Signing (step 4.4), you
  may later need to add Google's signing key SHA-256 as well (found in Play
  Console → App integrity → App signing key certificate).

[x] Done

---

## Block 5 — Final wiring (after Blocks 2–4)

### 5.1 Set App Check enforcement

- **Where:** [Firebase Console → App Check → APIs](https://console.firebase.google.com/project/onebytwo-avtanshgupta/appcheck)
- **Steps:**
  1. Click the **APIs** tab.
  2. For **Cloud Firestore**: click the three-dot menu → set to "Allow with
     monitoring" (pre-launch) or "Enforce" (48 hours post-launch).
  3. Repeat for **Cloud Storage**.
  4. **Cloud Functions:** There is no console toggle for Cloud Functions.
     Enforcement is done **in code** by verifying the App Check token in each
     function. This will be implemented when Cloud Functions code is written
     (skeleton PR and beyond). See:
     [Firebase App Check for Cloud Functions docs](https://firebase.google.com/docs/app-check/cloud-functions)
- **Expected result:** Firestore and Storage show "Allow with monitoring"
  (pre-launch) or "Enforced" (post-launch). Cloud Functions enforcement is
  deferred to the code implementation phase.

[x] Done

---

### 5.2 Generate App Check debug tokens

- **Where:** [Firebase Console → App Check](https://console.firebase.google.com/project/onebytwo-avtanshgupta/appcheck)
- **Steps:**
  1. Click on an app → overflow menu (**⋮**) → **Manage debug tokens**.
  2. Click **Add debug token**.
  3. Name it descriptively: `local-dev-avtansh`.
  4. Copy the generated token.
  5. Store the token in 1Password (team vault). NEVER in the repo.
  6. Repeat for each developer machine that needs local testing.
- **Expected result:** At least one debug token appears in the list per app.

[ ] Done

---

### 5.3 Upload all GitHub secrets

- **Where:** Your local terminal
- **Steps:**
  1. Create the `.secrets/` directory at the repo root:
     ```bash
     mkdir -p .secrets
     ```
  2. Place one file per secret, named exactly as the secret name:
     ```
     .secrets/ANDROID_KEYSTORE_BASE64
     .secrets/ANDROID_KEYSTORE_PASSWORD
     .secrets/KEY_ALIAS
     .secrets/KEY_PASSWORD
     .secrets/PLAY_SERVICE_ACCOUNT_JSON
     .secrets/APP_STORE_CONNECT_API_KEY_ID
     .secrets/ISSUER_ID
     .secrets/KEY_BASE64
     .secrets/MATCH_GIT_URL
     .secrets/MATCH_PASSWORD
     ```
  3. Run the upload script:
     ```bash
     bash scripts/stores/upload-github-secrets.sh
     ```
  4. Verify in [GitHub → Settings → Secrets → Actions](https://github.com/avtansh-code/OneByTwo/settings/secrets/actions).
  5. Delete the local `.secrets/` directory:
     ```bash
     rm -rf .secrets
     ```
- **Expected result:** All 11 secrets appear in the GitHub repository's Actions
  secrets page. `FIREBASE_SERVICE_ACCOUNT_JSON` is already uploaded (12 total).
- **Note:** `FIREBASE_TOKEN` (`firebase login:ci`) is deprecated and removed.
  Workflows use `FIREBASE_SERVICE_ACCOUNT_JSON` with
  `google-github-actions/auth` for Firebase deploys instead.

[x] Done

---

### 5.5 Stakeholder sign-off on billing

- **Where:** Review `docs/setup/00-decisions.md` section 5
- **Steps:**
  1. Confirm the billing owner is correct (avtanshgupta).
  2. Confirm the INR 5,000/month budget cap is appropriate.
  3. Confirm budget alert thresholds are configured (step 1.1).
- **Expected result:** Stakeholder verbally or in writing confirms billing setup.

[x] Done

---

## Block 6 — Cleanup (after everything above)

### 6.1 Remove old Firebase app registrations

- **Where:** [Firebase Console → Project Settings → Your apps](https://console.firebase.google.com/project/onebytwo-avtanshgupta/settings/general)
- **Steps:**
  1. Find the old `OneByTwo iOS` app (bundle `app.onebytwo`, app ID
     `1:1013666369675:ios:899dbb29bf0b4e852d848e`).
  2. Click the overflow menu → **Remove this app**.
  3. Find the old `OneByTwo Android` app (package `app.onebytwo`, app ID
     `1:1013666369675:android:771bfe5cf8ac093a2d848e`).
  4. Click the overflow menu → **Remove this app**.
- **Expected result:** Only two apps remain:
  - `One By Two` (iOS, `com.avtanshgupta.onebytwo`)
  - `One By Two Android` (Android, `com.avtanshgupta.onebytwo`)

[x] Done

---

## Progress Summary

| Block | Tasks | Description |
|---|---|---|
| Block 1 | 1.1–1.12 | Firebase Console — no dependencies |
| Block 2 | 2.1–2.6 | Apple Developer Portal — produces keys for Block 3 |
| Block 3 | 3.1–3.2 | Firebase Console — requires Apple keys |
| Block 4 | 4.1–4.6 | Google Play Console — independent of Block 2 |
| Block 5 | 5.1–5.5 | Final wiring — after Blocks 2–4 |
| Block 6 | 6.1 | Cleanup — remove old app registrations |

**Total: 29 tasks**
