#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────────────
# One By Two — 07: Register iOS and Android apps with Firebase
# Creates the app registrations and downloads the config files to _artifacts/.
# ────────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_helpers.sh"

require_var FIREBASE_PROJECT_ID
require_var IOS_BUNDLE_ID
require_var IOS_DISPLAY_NAME
require_var ANDROID_PACKAGE_NAME
require_var ANDROID_DISPLAY_NAME

step "Registering apps with Firebase project: ${FIREBASE_PROJECT_ID}"

# ── Helper: check if an app already exists ────────────────────────────────────
app_exists() {
  local platform="$1"  # IOS or ANDROID
  local app_id="$2"    # bundle ID or package name
  firebase apps:list "${platform}" --project "${FIREBASE_PROJECT_ID}" --json 2>/dev/null \
    | jq -e --arg aid "${app_id}" '.result[] | select(.appId != null) | select(.bundleId == $aid or .packageName == $aid)' >/dev/null 2>&1
}

# ── iOS app ───────────────────────────────────────────────────────────────────
info "Registering iOS app (${IOS_BUNDLE_ID})..."
if app_exists "IOS" "${IOS_BUNDLE_ID}"; then
  ok "iOS app '${IOS_BUNDLE_ID}' already registered. Skipping creation."
else
  firebase apps:create IOS "${IOS_DISPLAY_NAME}" \
    --bundle-id "${IOS_BUNDLE_ID}" \
    --project "${FIREBASE_PROJECT_ID}"
  ok "iOS app '${IOS_BUNDLE_ID}' registered as '${IOS_DISPLAY_NAME}'."
fi

# Download GoogleService-Info.plist
info "Downloading GoogleService-Info.plist..."
IOS_APP_ID="$(firebase apps:list IOS --project "${FIREBASE_PROJECT_ID}" --json 2>/dev/null \
  | jq -r --arg bid "${IOS_BUNDLE_ID}" '[.result[] | select(.bundleId == $bid)] | .[0].appId')"

if [[ -n "${IOS_APP_ID}" && "${IOS_APP_ID}" != "null" ]]; then
  firebase apps:sdkconfig IOS "${IOS_APP_ID}" \
    --project "${FIREBASE_PROJECT_ID}" \
    --out "${ARTIFACTS_DIR}/GoogleService-Info.plist"
  ok "GoogleService-Info.plist saved to ${ARTIFACTS_DIR}/"
else
  warn "Could not determine iOS app ID. Download GoogleService-Info.plist manually from the Firebase Console."
fi

# ── Android app ───────────────────────────────────────────────────────────────
info "Registering Android app (${ANDROID_PACKAGE_NAME})..."
if app_exists "ANDROID" "${ANDROID_PACKAGE_NAME}"; then
  ok "Android app '${ANDROID_PACKAGE_NAME}' already registered. Skipping creation."
else
  firebase apps:create ANDROID "${ANDROID_DISPLAY_NAME}" \
    --package-name "${ANDROID_PACKAGE_NAME}" \
    --project "${FIREBASE_PROJECT_ID}"
  ok "Android app '${ANDROID_PACKAGE_NAME}' registered as '${ANDROID_DISPLAY_NAME}'."
fi

# Download google-services.json
info "Downloading google-services.json..."
ANDROID_APP_ID="$(firebase apps:list ANDROID --project "${FIREBASE_PROJECT_ID}" --json 2>/dev/null \
  | jq -r --arg pkg "${ANDROID_PACKAGE_NAME}" '[.result[] | select(.packageName == $pkg)] | .[0].appId')"

if [[ -n "${ANDROID_APP_ID}" && "${ANDROID_APP_ID}" != "null" ]]; then
  firebase apps:sdkconfig ANDROID "${ANDROID_APP_ID}" \
    --project "${FIREBASE_PROJECT_ID}" \
    --out "${ARTIFACTS_DIR}/google-services.json"
  ok "google-services.json saved to ${ARTIFACTS_DIR}/"
else
  warn "Could not determine Android app ID. Download google-services.json manually from the Firebase Console."
fi

# ── Post-registration instructions ────────────────────────────────────────────
printf "\n"
ok "Both apps registered with Firebase."
printf "\n"
info "Next steps (after the skeleton Flutter project exists):"
printf "  1. Copy %s/GoogleService-Info.plist to ios/Runner/\n" "${ARTIFACTS_DIR}"
printf "  2. Copy %s/google-services.json     to android/app/\n" "${ARTIFACTS_DIR}"
printf "  3. These files are gitignored. Each developer downloads their own copy.\n"
