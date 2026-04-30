#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────────────
# One By Two — 06: Seed Firebase Remote Config
# Sets the initial Remote Config keys from remote-config.template.json.
# See docs/setup/00-decisions.md section 7 for the key definitions.
# ────────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_helpers.sh"

require_var FIREBASE_PROJECT_ID

TEMPLATE_FILE="${SCRIPT_DIR}/remote-config.template.json"

step "Seeding Firebase Remote Config"

# ── Validate template file ────────────────────────────────────────────────────
if [[ ! -f "${TEMPLATE_FILE}" ]]; then
  err "Remote Config template not found at ${TEMPLATE_FILE}."
  exit 1
fi
if ! jq empty "${TEMPLATE_FILE}" 2>/dev/null; then
  err "Remote Config template is not valid JSON."
  exit 1
fi
ok "Template file validated: ${TEMPLATE_FILE}"

# ── Get access token ─────────────────────────────────────────────────────────
info "Obtaining access token..."
ACCESS_TOKEN="$(gcloud auth print-access-token 2>/dev/null)"
if [[ -z "${ACCESS_TOKEN}" ]]; then
  err "Failed to obtain access token. Ensure gcloud is authenticated."
  exit 1
fi

# ── Fetch current etag ───────────────────────────────────────────────────────
info "Fetching current Remote Config state..."
RC_URL="https://firebaseremoteconfig.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/remoteConfig"

CURRENT_RC="$(curl -sS \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "x-goog-user-project: ${FIREBASE_PROJECT_ID}" \
  -H "Accept-Encoding: gzip" \
  "${RC_URL}" 2>/dev/null || true)"

CURRENT_ETAG="$(curl -sS -I \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "x-goog-user-project: ${FIREBASE_PROJECT_ID}" \
  "${RC_URL}" 2>/dev/null | grep -i 'etag:' | tr -d '\r' | awk '{print $2}' || true)"

if [[ -z "${CURRENT_ETAG}" ]]; then
  warn "Could not fetch current etag. Using '*' (force overwrite)."
  CURRENT_ETAG="*"
fi
ok "Current etag: ${CURRENT_ETAG}"

# ── Push the template ────────────────────────────────────────────────────────
info "Publishing Remote Config template..."
HTTP_CODE="$(curl -sS -o /dev/null -w '%{http_code}' \
  -X PUT \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json; UTF-8" \
  -H "If-Match: ${CURRENT_ETAG}" \
  -H "x-goog-user-project: ${FIREBASE_PROJECT_ID}" \
  -d @"${TEMPLATE_FILE}" \
  "${RC_URL}")"

if [[ "${HTTP_CODE}" -ge 200 && "${HTTP_CODE}" -lt 300 ]]; then
  ok "Remote Config template published (HTTP ${HTTP_CODE})."
else
  err "Failed to publish Remote Config template (HTTP ${HTTP_CODE})."
  printf "  If HTTP 409: another update occurred. Re-run this script.\n"
  printf "  If HTTP 403: ensure the Firebase Remote Config API is enabled.\n"
  exit 1
fi

printf "\n"
ok "Remote Config seeded with initial keys."
