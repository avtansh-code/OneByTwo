#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────────────
# One By Two — 02: Enable required Google Cloud APIs
# Enables all GCP APIs needed by Firebase services.
# See docs/setup/00-decisions.md section 11 for the full list.
# ────────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_helpers.sh"

require_var FIREBASE_PROJECT_ID

step "Enabling Google Cloud APIs for project: ${FIREBASE_PROJECT_ID}"

APIS=(
  "firebase.googleapis.com"
  "identitytoolkit.googleapis.com"
  "firestore.googleapis.com"
  "firebaseremoteconfig.googleapis.com"
  "firebasestorage.googleapis.com"
  "fcm.googleapis.com"
  "cloudfunctions.googleapis.com"
  "cloudbuild.googleapis.com"
  "secretmanager.googleapis.com"
  "recaptchaenterprise.googleapis.com"
)

for api in "${APIS[@]}"; do
  info "Enabling ${api}..."
  if gcloud services list --enabled --filter="config.name:${api}" --format='value(config.name)' --project="${FIREBASE_PROJECT_ID}" 2>/dev/null | grep -q "${api}"; then
    ok "${api} — already enabled."
  else
    gcloud services enable "${api}" --project="${FIREBASE_PROJECT_ID}" --quiet
    ok "${api} — enabled."
  fi
done

printf "\n"
ok "All required APIs enabled."
