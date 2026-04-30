# App Store Registration

This document covers the iOS and Android app store registration steps that must
happen NOW — before the skeleton bootstrap PR — so that bundle/application IDs
are reserved and credentials needed by Firebase and CI are produced.

Source of truth for all identifiers: `docs/setup/00-decisions.md`.

---

## Apple App Store Connect

### 4.1 Create the App Record

| Field | Value |
|---|---|
| **Navigate** | [App Store Connect](https://appstoreconnect.apple.com/) → My Apps → "+" → New App |
| **Platform** | iOS |
| **Name** | `One By Two` (confirm availability — names are unique per-platform) |
| **Primary language** | English (U.K.) |
| **Bundle ID** | `com.avtanshgupta.onebytwo` (must match the Xcode-registered identifier; create it in the Certificates, Identifiers & Profiles portal first if it does not exist) |
| **SKU** | `onebytwo-ios-v1` |
| **User access** | Full Access |
| **Done when** | The app record appears in the My Apps list with status "Prepare for Submission". |
| **Reference** | SRS section 3.4; docs/setup/00-decisions.md section 2 |

**Pre-requisite:** Register the Bundle ID `com.avtanshgupta.onebytwo` in the Apple Developer
portal → Certificates, Identifiers & Profiles → Identifiers → App IDs before
creating the App Store Connect record.

`[ ] Done by __________ on __________`

---

### 4.2 Create APNs Authentication Key

This key is used by Firebase Cloud Messaging to send push notifications to iOS
devices.

| Field | Value |
|---|---|
| **Navigate** | Apple Developer Portal → Certificates, Identifiers & Profiles → Keys → "+" |
| **Key name** | `One By Two APNs` |
| **Services** | Check **Apple Push Notifications service (APNs)** |
| **Action** | Click Continue → Register. Download the `.p8` key file. |
| **Done when** | A `.p8` file is downloaded. Note the **Key ID** displayed on the confirmation page. |

**Credential produced:**

| Credential | Store in | Used by |
|---|---|---|
| `.p8` key file | 1Password (team vault) — NEVER the repo | Firebase Console (section 3.4.2 of the console checklist) |
| Key ID | 1Password alongside the `.p8` | Firebase Console APNs config |
| Team ID | `S6ULATL6PT` (already known) | Firebase Console APNs config |

`[ ] Done by __________ on __________`

---

### 4.3 Create DeviceCheck Key

This key is used by Firebase App Check to verify that requests come from a
genuine iOS device.

| Field | Value |
|---|---|
| **Navigate** | Apple Developer Portal → Certificates, Identifiers & Profiles → Keys → "+" |
| **Key name** | `One By Two DeviceCheck` |
| **Services** | Check **DeviceCheck** |
| **Action** | Click Continue → Register. Download the `.p8` key file. |
| **Done when** | A `.p8` file is downloaded. Note the **Key ID**. |

**Credential produced:**

| Credential | Store in | Used by |
|---|---|---|
| `.p8` key file | 1Password (team vault) — NEVER the repo | Firebase Console App Check (section 3.3.1 of the console checklist) |
| Key ID | 1Password alongside the `.p8` | Firebase Console App Check config |
| Team ID | `S6ULATL6PT` (already known) | Firebase Console App Check config |

**Note:** Apple allows a maximum of 2 keys per account. If you already have 2
keys, you can reuse an existing key that has both APNs and DeviceCheck services
enabled. In that case, sections 4.2 and 4.3 can share a single key.

`[ ] Done by __________ on __________`

---

### 4.4 Create App Store Connect API Key

This key is used by Fastlane to upload builds to TestFlight and the App Store
without interactive authentication.

| Field | Value |
|---|---|
| **Navigate** | [App Store Connect](https://appstoreconnect.apple.com/) → Users and Access → Integrations → App Store Connect API → Keys → "+" |
| **Name** | `One By Two CI` |
| **Role** | **App Manager** (minimum role for TestFlight uploads) |
| **Action** | Click Generate. Download the `.p8` API key file. Note the **Key ID** and **Issuer ID** (shown at the top of the Keys page). |
| **Done when** | The API key appears in the list with status "Active". |

**Credentials produced → GitHub Secrets:**

| Credential | GitHub Secret Name (SRS §9.3) | Format |
|---|---|---|
| Key ID | `APP_STORE_CONNECT_API_KEY_ID` | Plain text |
| Issuer ID | `ISSUER_ID` | Plain text |
| `.p8` file (base64-encoded) | `KEY_BASE64` | `base64 -i AuthKey_XXXXXXXX.p8` |

**Storage:** The raw `.p8` file goes in 1Password. The base64-encoded value goes
into the GitHub secret.

`[ ] Done by __________ on __________`

---

### 4.5 Set Up Fastlane Match

Fastlane match stores iOS certificates and provisioning profiles in a dedicated
private Git repository, enabling CI to sign builds without manual certificate
management.

| Step | Action |
|---|---|
| **Create match repo** | Create a **private** GitHub repository (e.g., `avtansh-code/onebytwo-match-certs`). It must be empty (no README). |
| **Choose passphrase** | Generate a strong passphrase for encrypting the match repo contents. Store in 1Password. |
| **Done when** | The private repo exists and is empty. The passphrase is stored in 1Password. |

**Credentials produced → GitHub Secrets:**

| Credential | GitHub Secret Name (SRS §9.3) | Format |
|---|---|---|
| Match repo Git URL | `MATCH_GIT_URL` | `https://github.com/avtansh-code/onebytwo-match-certs.git` (or SSH URL) |
| Match passphrase | `MATCH_PASSWORD` | Plain text |

`[ ] Done by __________ on __________`

---

### 4.6 Create iOS Distribution Certificate and Profiles

This step can be deferred until just before the first TestFlight upload, but the
match repo and credentials (section 4.5) must exist now.

| Step | Action |
|---|---|
| **Run match** | From the repo root (once Fastlane is configured in the skeleton PR): `fastlane match appstore --git_url <MATCH_GIT_URL>` |
| **First run** | Match will create a new Apple Distribution certificate, download it, and store it encrypted in the match repo. It will also create an App Store provisioning profile for `com.avtanshgupta.onebytwo`. |
| **Done when** | The match repo contains encrypted certificate and profile files. `fastlane match appstore` completes without errors. |

**Note:** This step requires Fastlane to be installed and a `Matchfile`
configured. Both are created as part of the skeleton bootstrap PR, not this
setup phase. Mark this item as deferred until then.

`[ ] Deferred until skeleton PR — match repo and credentials ready`

---

## Google Play Console

### 4.7 Create the App Record

| Field | Value |
|---|---|
| **Navigate** | [Google Play Console](https://play.google.com/console/) → All apps → Create app |
| **App name** | `One By Two` |
| **Default language** | English (United Kingdom) |
| **App or game** | App |
| **Free or paid** | Free |
| **Declarations** | Accept the Developer Program Policies and US export laws declarations. |
| **Done when** | The app appears in the All Apps list. The application ID `com.avtanshgupta.onebytwo` is set in the Android project's `build.gradle`, not in the Play Console directly. |
| **Reference** | SRS section 3.4; docs/setup/00-decisions.md section 2 |

**Developer contact details:** Set the developer name, email, and website as
required by the Play Console. Use `support@onebytwo.app` for the support email
(or the stakeholder-confirmed address).

`[ ] Done by __________ on __________`

---

### 4.8 Configure Internal Testing Track

| Field | Value |
|---|---|
| **Navigate** | Play Console → `One By Two` → Testing → Internal testing |
| **Action** | Create an internal testing track. Add a testers list with at least the stakeholder's Google account email. The first `.aab` upload will happen via CI. |
| **Done when** | Internal testing track exists with at least one tester email. |
| **Reference** | SRS section 9.2.2 |

`[ ] Done by __________ on __________`

---

### 4.9 Generate Android Upload Key (Keystore)

The upload key is used to sign the app bundle before uploading to Play Console.
Google manages the actual signing key via Play App Signing (section 4.11).

| Step | Action |
|---|---|
| **Generate keystore** | Run: `keytool -genkey -v -keystore onebytwo-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias onebytwo-upload` |
| **Prompts** | Enter a strong password for the keystore and for the key. Use `onebytwo-upload` as the key alias. Fill in the certificate fields (CN, OU, etc.) with your details. |
| **Store securely** | Place the `.jks` file in 1Password (team vault). NEVER commit it to the repository. |
| **Done when** | The `.jks` file exists in 1Password. |

**Credentials produced → GitHub Secrets:**

| Credential | GitHub Secret Name (SRS §9.3) | Format |
|---|---|---|
| `.jks` file (base64-encoded) | `ANDROID_KEYSTORE_BASE64` | `base64 -i onebytwo-upload.jks` |
| Keystore password | `ANDROID_KEYSTORE_PASSWORD` | Plain text |
| Key alias | `KEY_ALIAS` | `onebytwo-upload` |
| Key password | `KEY_PASSWORD` | Plain text |

`[ ] Done by __________ on __________`

---

### 4.10 Create Play Console Service Account

This service account is used by Fastlane (`supply`) to upload `.aab` files to
the Play Console from CI.

| Step | Action |
|---|---|
| **Navigate** | Google Cloud Console → IAM & Admin → Service Accounts → Create |
| **Name** | `play-store-uploader` |
| **Role** | No GCP roles needed (the role is granted in Play Console) |
| **Key** | Create a JSON key and download it. |
| **Play Console** | Go to Play Console → Users and permissions → Invite new users. Paste the service account email. Grant release permissions (create/edit/delete drafts, release to production, manage testing tracks) and add the `One By Two` app under App permissions. |
| **Done when** | The service account appears in Play Console → Users and permissions with release permissions for the app. |

**Credential produced → GitHub Secret:**

| Credential | GitHub Secret Name (SRS §9.3) | Format |
|---|---|---|
| JSON key file | `PLAY_SERVICE_ACCOUNT_JSON` | Raw JSON (or base64-encoded, depending on Fastlane config) |

**Storage:** The raw JSON key goes in 1Password. Upload to GitHub secrets
using `scripts/stores/upload-github-secrets.sh` (Phase 5).

`[ ] Done by __________ on __________`

---

### 4.11 Set Up Play App Signing

| Field | Value |
|---|---|
| **Navigate** | Play Console → `One By Two` → Setup → App signing |
| **Action** | Opt in to **Google Play App Signing**. Choose "Upload my own existing key" and upload the public certificate from the upload keystore created in section 4.9. Extract it with: `keytool -export -rfc -keystore onebytwo-upload.jks -alias onebytwo-upload -file upload-cert.pem` |
| **Done when** | Play App Signing shows as enabled. The upload key fingerprint matches the one from your keystore. Google now manages the actual signing key. |
| **Reference** | Best practice for Android app signing |

**Note:** Play App Signing is strongly recommended. Google manages the actual
signing key and can re-sign the app if the upload key is compromised. The upload
key is what CI uses; the signing key never leaves Google.

`[ ] Done by __________ on __________`

---

## Credential-to-Secret Mapping Summary

Every credential produced in this phase maps to a GitHub secret from SRS §9.3:

| Phase Section | Credential | GitHub Secret Name |
|---|---|---|
| 4.4 | App Store Connect API Key ID | `APP_STORE_CONNECT_API_KEY_ID` |
| 4.4 | App Store Connect Issuer ID | `ISSUER_ID` |
| 4.4 | App Store Connect API Key (.p8, base64) | `KEY_BASE64` |
| 4.5 | Fastlane match Git URL | `MATCH_GIT_URL` |
| 4.5 | Fastlane match passphrase | `MATCH_PASSWORD` |
| 4.9 | Android keystore (.jks, base64) | `ANDROID_KEYSTORE_BASE64` |
| 4.9 | Keystore password | `ANDROID_KEYSTORE_PASSWORD` |
| 4.9 | Key alias | `KEY_ALIAS` |
| 4.9 | Key password | `KEY_PASSWORD` |
| 4.10 | Play Console service account JSON | `PLAY_SERVICE_ACCOUNT_JSON` |

Credentials NOT mapped to GitHub secrets (used in Firebase Console only):

| Phase Section | Credential | Used in |
|---|---|---|
| 4.2 | APNs key (.p8) + Key ID | Firebase Console → FCM → APNs config |
| 4.3 | DeviceCheck key (.p8) + Key ID | Firebase Console → App Check → iOS |
