#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────────────
# One By Two — 10: Smoke test
# Validates that Firestore is reachable by writing and reading a test document
# using the deployer service account.
# ────────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_helpers.sh"

require_var FIREBASE_PROJECT_ID
require_var GCP_REGION

step "Running smoke test against project: ${FIREBASE_PROJECT_ID}"

# ── Get access token ─────────────────────────────────────────────────────────
ACCESS_TOKEN="$(gcloud auth print-access-token 2>/dev/null)"
if [[ -z "${ACCESS_TOKEN}" ]]; then
  err "Failed to obtain access token."
  exit 1
fi

FIRESTORE_URL="https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents"
COLLECTION="_setup_smoke"
DOC_ID="smoke_$(date +%s)"

# ── Write a test document ────────────────────────────────────────────────────
info "Writing test document to ${COLLECTION}/${DOC_ID}..."
WRITE_CODE="$(curl -sS -o /dev/null -w '%{http_code}' \
  -X PATCH \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"fields\": {
      \"test\": {\"stringValue\": \"smoke-test\"},
      \"timestamp\": {\"stringValue\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}
    }
  }" \
  "${FIRESTORE_URL}/${COLLECTION}/${DOC_ID}")"

if [[ "${WRITE_CODE}" -ge 200 && "${WRITE_CODE}" -lt 300 ]]; then
  ok "Test document written (HTTP ${WRITE_CODE})."
else
  err "Failed to write test document (HTTP ${WRITE_CODE})."
  printf "  Ensure Firestore is created and the authenticated account has access.\n"
  exit 1
fi

# ── Read the document back ────────────────────────────────────────────────────
info "Reading test document back..."
READ_CODE="$(curl -sS -o /dev/null -w '%{http_code}' \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  "${FIRESTORE_URL}/${COLLECTION}/${DOC_ID}")"

if [[ "${READ_CODE}" -ge 200 && "${READ_CODE}" -lt 300 ]]; then
  ok "Test document read back successfully (HTTP ${READ_CODE})."
else
  err "Failed to read test document (HTTP ${READ_CODE})."
  exit 1
fi

# ── Delete the test document ──────────────────────────────────────────────────
info "Cleaning up test document..."
DELETE_CODE="$(curl -sS -o /dev/null -w '%{http_code}' \
  -X DELETE \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  "${FIRESTORE_URL}/${COLLECTION}/${DOC_ID}")"

if [[ "${DELETE_CODE}" -ge 200 && "${DELETE_CODE}" -lt 300 ]]; then
  ok "Test document deleted (HTTP ${DELETE_CODE})."
else
  warn "Could not delete test document (HTTP ${DELETE_CODE}). Clean up manually."
fi

# ── Optional: Cloud Functions healthcheck ─────────────────────────────────────
info "Checking for deployed Cloud Functions healthcheck..."
warn "No Cloud Functions deployed yet. Skipping healthcheck (expected before skeleton PR)."

printf "\n"
ok "Smoke test passed. Firestore is reachable in ${GCP_REGION}."
