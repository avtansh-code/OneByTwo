#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────────────
# One By Two — 01: Link Firebase project
# Sets the active Firebase project, writes .firebaserc, and verifies Blaze billing.
# ────────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_helpers.sh"

require_var FIREBASE_PROJECT_ID

step "Linking Firebase project: ${FIREBASE_PROJECT_ID}"

# ── Verify the project exists ─────────────────────────────────────────────────
info "Verifying project exists..."
if ! firebase projects:list --json 2>/dev/null | jq -e --arg pid "${FIREBASE_PROJECT_ID}" '.result[] | select(.projectId == $pid)' >/dev/null 2>&1; then
  err "Firebase project '${FIREBASE_PROJECT_ID}' not found in your account."
  printf "  Ensure the project exists at https://console.firebase.google.com/\n"
  printf "  and that your authenticated account has access.\n"
  exit 1
fi
ok "Project '${FIREBASE_PROJECT_ID}' found."

# ── Set gcloud project ───────────────────────────────────────────────────────
info "Setting gcloud project..."
gcloud config set project "${FIREBASE_PROJECT_ID}" --quiet
ok "gcloud project set to '${FIREBASE_PROJECT_ID}'."

# ── Write .firebaserc ────────────────────────────────────────────────────────
info "Writing .firebaserc..."
FIREBASERC_PATH="${REPO_ROOT}/.firebaserc"
cat > "${FIREBASERC_PATH}" <<EOF
{
  "projects": {
    "default": "${FIREBASE_PROJECT_ID}"
  }
}
EOF
ok ".firebaserc written with default project '${FIREBASE_PROJECT_ID}'."

# ── Set Firebase CLI active project ───────────────────────────────────────────
info "Setting Firebase CLI active project..."
firebase use "${FIREBASE_PROJECT_ID}" --add --alias default 2>/dev/null || \
  firebase use "${FIREBASE_PROJECT_ID}" 2>/dev/null || true
ok "Firebase CLI active project set."

# ── Verify Blaze billing ─────────────────────────────────────────────────────
info "Checking billing plan (Blaze required)..."
BILLING_INFO="$(gcloud billing projects describe "${FIREBASE_PROJECT_ID}" --format='value(billingAccountName)' 2>/dev/null || true)"
if [[ -z "${BILLING_INFO}" ]]; then
  err "No billing account linked to project '${FIREBASE_PROJECT_ID}'."
  printf "  The Blaze (pay-as-you-go) plan is required for Cloud Functions and Phone Auth.\n"
  printf "  Enable it at: https://console.firebase.google.com/project/${FIREBASE_PROJECT_ID}/usage/details\n"
  exit 1
fi
ok "Billing account linked: ${BILLING_INFO}"
warn "Manually verify the plan is Blaze (pay-as-you-go) in the Firebase Console."
warn "Budget alerts (50%%, 90%%, 100%% of INR 5,000/month) must be configured by hand."

printf "\n"
ok "Project linked successfully."
