#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────────────
# One By Two — 05: Deploy Firestore rules, indexes, and Storage rules
# Deploys security rules and indexes from the repo root.
# Used for both initial setup and ongoing CI deploys.
# ────────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_helpers.sh"

require_var FIREBASE_PROJECT_ID

step "Deploying Firestore rules, indexes, and Storage rules"

cd "${REPO_ROOT}"

# ── Check for required files ──────────────────────────────────────────────────
RULES_FILES=("firestore.rules" "firestore.indexes.json" "storage.rules")
for f in "${RULES_FILES[@]}"; do
  if [[ ! -f "${f}" ]]; then
    err "Required file '${f}' not found in repo root (${REPO_ROOT})."
    printf "  This file must exist before rules can be deployed.\n"
    printf "  If this is the initial setup, create a default-deny baseline first.\n"
    exit 1
  fi
  ok "Found ${f}"
done

# ── Deploy Firestore rules and indexes ────────────────────────────────────────
info "Deploying Firestore rules and indexes..."
firebase deploy \
  --only firestore:rules,firestore:indexes \
  --project "${FIREBASE_PROJECT_ID}" \
  --force

ok "Firestore rules and indexes deployed."

# ── Deploy Storage rules ──────────────────────────────────────────────────────
info "Deploying Storage rules..."
firebase deploy \
  --only storage \
  --project "${FIREBASE_PROJECT_ID}" \
  --force

ok "Storage rules deployed."

printf "\n"
ok "All rules and indexes deployed successfully."
