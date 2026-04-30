# Secrets Manifest

Single table listing every secret required in GitHub Actions. All secret names
match SRS section 9.3 verbatim. The "Source" column points at the Phase 3 or
Phase 4 section that produces the credential.

Source of truth for configuration values: `docs/setup/00-decisions.md`.

---

## GitHub Actions Secrets

| Secret Name | Source | Format | Rotation Policy | Used By Workflow |
|---|---|---|---|---|
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Phase 2 script `08-create-deployer-sa.sh` output (`_artifacts/github-actions-deployer.json`) | JSON key file (raw JSON) | Rotate annually | PR pipeline, Release pipeline — Firebase deploys via `google-github-actions/auth` |
| `ANDROID_KEYSTORE_BASE64` | Phase 4 section 4.9 — Android upload keystore | Base64-encoded `.jks` file | Do not rotate (bound to Play App Signing upload key) | Release pipeline (`release.yml`) — Android build signing |
| `ANDROID_KEYSTORE_PASSWORD` | Phase 4 section 4.9 — keystore generation prompt | Plain text | Rotate only if compromised | Release pipeline (`release.yml`) — Android build signing |
| `KEY_ALIAS` | Phase 4 section 4.9 — keystore generation prompt | Plain text (value: `onebytwo-upload`) | Stable (matches keystore alias) | Release pipeline (`release.yml`) — Android build signing |
| `KEY_PASSWORD` | Phase 4 section 4.9 — keystore generation prompt | Plain text | Rotate only if compromised | Release pipeline (`release.yml`) — Android build signing |
| `PLAY_SERVICE_ACCOUNT_JSON` | Phase 4 section 4.10 — Play Console service account JSON key | JSON key file (raw JSON) | Rotate annually | Release pipeline (`release.yml`) — Fastlane `supply` upload to Play Internal Track |
| `APP_STORE_CONNECT_API_KEY_ID` | Phase 4 section 4.4 — App Store Connect API key | Plain text (Key ID string) | Rotate annually or on team change | Release pipeline (`release.yml`) — Fastlane `pilot` upload to TestFlight |
| `ISSUER_ID` | Phase 4 section 4.4 — App Store Connect Integrations page header | Plain text (Issuer ID string) | Stable (tied to Apple Developer team) | Release pipeline (`release.yml`) — Fastlane `pilot` upload to TestFlight |
| `KEY_BASE64` | Phase 4 section 4.4 — App Store Connect API key `.p8` file | Base64-encoded `.p8` file | Rotate annually | Release pipeline (`release.yml`) — Fastlane `pilot` upload to TestFlight |
| `MATCH_GIT_URL` | Phase 4 section 4.5 — Fastlane match private repo URL | Git URL (HTTPS or SSH) | Stable | Release pipeline (`release.yml`) — Fastlane `match` certificate sync |
| `MATCH_PASSWORD` | Phase 4 section 4.5 — passphrase chosen during match setup | Plain text passphrase | Rotate annually | Release pipeline (`release.yml`) — Fastlane `match` certificate sync |
| `OPS_NOTIFY_WEBHOOK` | Slack or Teams incoming webhook URL (created by stakeholder) | URL | Rotate on channel change | Release pipeline (`release.yml`) — post-release notification |

---

## Upload Procedure

1. Collect all credential files into a local `.secrets/` directory (gitignored).
2. Name each file to match the secret name exactly (e.g., `.secrets/FIREBASE_TOKEN`,
   `.secrets/ANDROID_KEYSTORE_BASE64`).
3. Run `scripts/stores/upload-github-secrets.sh` to upload all secrets at once.
4. Delete the local `.secrets/` directory after successful upload.

See `scripts/stores/upload-github-secrets.sh` for implementation.

---

## Credentials NOT Stored in GitHub (Firebase Console Only)

These credentials are used exclusively in the Firebase Console and are not
GitHub Actions secrets:

| Credential | Source | Stored in | Used in |
|---|---|---|---|
| APNs Authentication Key (.p8) | Phase 4 section 4.2 | 1Password | Firebase Console → FCM → APNs config |
| APNs Key ID | Phase 4 section 4.2 | 1Password | Firebase Console → FCM → APNs config |
| DeviceCheck Key (.p8) | Phase 4 section 4.3 | 1Password | Firebase Console → App Check → iOS |
| DeviceCheck Key ID | Phase 4 section 4.3 | 1Password | Firebase Console → App Check → iOS |
| App Check debug tokens | Console checklist section 3.3.4 | 1Password | Local dev `.env` files (per developer) |
