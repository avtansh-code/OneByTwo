#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────────────
# One By Two — 04: Create default Cloud Storage bucket
# Creates the default Firebase Storage bucket in the configured region.
# Idempotent: skips if the bucket already exists.
# ────────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_helpers.sh"

require_var FIREBASE_PROJECT_ID
require_var GCP_REGION

step "Verifying default Cloud Storage bucket"

# ── Check if bucket already exists ────────────────────────────────────────────
# Firebase Storage creates the default bucket via the Console or SDK. The bucket
# name may be <project>.firebasestorage.app or <project>.appspot.com depending
# on when the project was created.
info "Looking for existing Firebase Storage bucket..."
BUCKET_NAME="$(gcloud storage buckets list --project="${FIREBASE_PROJECT_ID}" --format='value(name)' 2>/dev/null | head -1 || true)"

if [[ -n "${BUCKET_NAME}" ]]; then
  BUCKET_LOCATION="$(gcloud storage buckets describe "gs://${BUCKET_NAME}" --format='value(location)' 2>/dev/null || true)"
  ok "Firebase Storage bucket found: ${BUCKET_NAME} (${BUCKET_LOCATION})."
else
  err "No Cloud Storage bucket found for project '${FIREBASE_PROJECT_ID}'."
  printf "  Firebase Storage must be initialised through the Console:\n"
  printf "  https://console.firebase.google.com/project/${FIREBASE_PROJECT_ID}/storage\n"
  printf "  Click 'Get Started' and select region '%s'.\n" "${GCP_REGION}"
  exit 1
fi

printf "\n"
ok "Cloud Storage setup complete."
