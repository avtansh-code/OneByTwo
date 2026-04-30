#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────────────
# One By Two — 09: Configure App Check
# Registers App Check attestation providers where the API supports it.
# Prints manual steps for anything that requires console interaction.
# ────────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_helpers.sh"

require_var FIREBASE_PROJECT_ID
require_var IOS_BUNDLE_ID
require_var ANDROID_PACKAGE_NAME
require_var APPLE_TEAM_ID

step "Configuring App Check for project: ${FIREBASE_PROJECT_ID}"

# ── Get access token ─────────────────────────────────────────────────────────
ACCESS_TOKEN="$(gcloud auth print-access-token 2>/dev/null)"
if [[ -z "${ACCESS_TOKEN}" ]]; then
  err "Failed to obtain access token."
  exit 1
fi

# ── Get app IDs ───────────────────────────────────────────────────────────────
info "Looking up registered app IDs..."
IOS_APP_ID="$(firebase apps:list IOS --project "${FIREBASE_PROJECT_ID}" --json 2>/dev/null \
  | jq -r --arg bid "${IOS_BUNDLE_ID}" '[.result[] | select(.bundleId == $bid)] | .[0].appId // empty')"

ANDROID_APP_ID="$(firebase apps:list ANDROID --project "${FIREBASE_PROJECT_ID}" --json 2>/dev/null \
  | jq -r --arg pkg "${ANDROID_PACKAGE_NAME}" '[.result[] | select(.packageName == $pkg)] | .[0].appId // empty')"

if [[ -z "${IOS_APP_ID}" ]]; then
  err "iOS app not found. Run 07-register-apps.sh first."
  exit 1
fi
if [[ -z "${ANDROID_APP_ID}" ]]; then
  err "Android app not found. Run 07-register-apps.sh first."
  exit 1
fi
ok "iOS app ID: ${IOS_APP_ID}"
ok "Android app ID: ${ANDROID_APP_ID}"

# ── Register iOS DeviceCheck provider ─────────────────────────────────────────
info "Registering iOS DeviceCheck provider via API..."
APPCHECK_URL="https://firebaseappcheck.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/apps/${IOS_APP_ID}/deviceCheckConfig"

HTTP_CODE="$(curl -sS -o /dev/null -w '%{http_code}' \
  -X PATCH \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"tokenTtl\": \"3600s\"}" \
  "${APPCHECK_URL}?updateMask=tokenTtl" 2>/dev/null || true)"

if [[ "${HTTP_CODE}" -ge 200 && "${HTTP_CODE}" -lt 300 ]]; then
  ok "iOS DeviceCheck provider registered (HTTP ${HTTP_CODE})."
else
  warn "Could not register iOS DeviceCheck via API (HTTP ${HTTP_CODE})."
  warn "This may require manual configuration in the Firebase Console."
fi

# ── Register Android Play Integrity provider ──────────────────────────────────
info "Registering Android Play Integrity provider via API..."
APPCHECK_URL="https://firebaseappcheck.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/apps/${ANDROID_APP_ID}/playIntegrityConfig"

HTTP_CODE="$(curl -sS -o /dev/null -w '%{http_code}' \
  -X PATCH \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"tokenTtl\": \"3600s\"}" \
  "${APPCHECK_URL}?updateMask=tokenTtl" 2>/dev/null || true)"

if [[ "${HTTP_CODE}" -ge 200 && "${HTTP_CODE}" -lt 300 ]]; then
  ok "Android Play Integrity provider registered (HTTP ${HTTP_CODE})."
else
  warn "Could not register Android Play Integrity via API (HTTP ${HTTP_CODE})."
  warn "This may require manual configuration in the Firebase Console."
fi

# ── Manual steps ──────────────────────────────────────────────────────────────
printf "\n"
ok "App Check API configuration attempted."
printf "\n"
info "Manual steps required in the Firebase Console:"
printf "  1. iOS DeviceCheck:\n"
printf "     - Navigate to: Firebase Console > App Check > Apps > iOS\n"
printf "     - Upload the DeviceCheck private key (.p8) from App Store Connect.\n"
printf "     - Enter Apple Team ID: %s\n" "${APPLE_TEAM_ID}"
printf "     - Enter the Key ID from App Store Connect.\n"
printf "\n"
printf "  2. Android Play Integrity:\n"
printf "     - Navigate to: Firebase Console > App Check > Apps > Android\n"
printf "     - Play Integrity should be auto-configured once the app is in Play Console.\n"
printf "\n"
printf "  3. Enforcement:\n"
printf "     - Set Firestore, Storage, and Cloud Functions to 'Allow with monitoring' initially.\n"
printf "     - Switch to 'Enforce' 48 hours after launch (per SRS section 11.2).\n"
printf "\n"
printf "  4. Debug tokens:\n"
printf "     - Generate one debug token per developer in the Firebase Console.\n"
printf "     - Store tokens in your team vault (1Password). NEVER commit them.\n"
