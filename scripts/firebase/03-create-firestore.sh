#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────────────
# One By Two — 03: Create Cloud Firestore database
# Creates the Firestore database in Native mode in the configured region.
# Idempotent: skips if the database already exists in the correct region.
# ────────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_helpers.sh"

require_var FIREBASE_PROJECT_ID
require_var GCP_REGION

step "Creating Cloud Firestore database in ${GCP_REGION}"

# ── Check if Firestore already exists ─────────────────────────────────────────
info "Checking for existing Firestore database..."
EXISTING_DB="$(gcloud firestore databases describe --project="${FIREBASE_PROJECT_ID}" --format='json' 2>/dev/null || true)"

if [[ -n "${EXISTING_DB}" && "${EXISTING_DB}" != "null" ]]; then
  EXISTING_REGION="$(echo "${EXISTING_DB}" | jq -r '.locationId // empty')"
  EXISTING_TYPE="$(echo "${EXISTING_DB}" | jq -r '.type // empty')"

  if [[ "${EXISTING_REGION}" == "${GCP_REGION}" ]]; then
    ok "Firestore database already exists in ${EXISTING_REGION} (${EXISTING_TYPE} mode). No action needed."
    exit 0
  else
    err "Firestore database exists in region '${EXISTING_REGION}', but config.env specifies '${GCP_REGION}'."
    printf "  Firestore region is IMMUTABLE after creation.\n"
    printf "  If this is the wrong region, you must create a new Firebase project.\n"
    exit 1
  fi
fi

# ── Create the database ──────────────────────────────────────────────────────
info "Creating Firestore database (Native mode, region: ${GCP_REGION})..."
gcloud firestore databases create \
  --project="${FIREBASE_PROJECT_ID}" \
  --location="${GCP_REGION}" \
  --type=firestore-native \
  --quiet

ok "Firestore database created in ${GCP_REGION} (Native mode)."

printf "\n"
ok "Firestore setup complete."
