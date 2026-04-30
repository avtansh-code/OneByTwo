#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────────────
# One By Two — 00: Pre-requisite checks
# Verifies that all required CLI tools are installed and authenticated.
# ────────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_helpers.sh"

step "Checking pre-requisites"

# ── Firebase CLI ──────────────────────────────────────────────────────────────
info "Checking Firebase CLI..."
if ! command -v firebase >/dev/null 2>&1; then
  err "Firebase CLI not found."
  printf "  Install: npm install -g firebase-tools\n"
  printf "  Docs:    https://firebase.google.com/docs/cli\n"
  exit 1
fi
FIREBASE_VERSION="$(firebase --version 2>/dev/null || true)"
ok "Firebase CLI: ${FIREBASE_VERSION}"

# ── gcloud CLI ────────────────────────────────────────────────────────────────
info "Checking gcloud CLI..."
if ! command -v gcloud >/dev/null 2>&1; then
  err "gcloud CLI not found."
  printf "  Install: https://cloud.google.com/sdk/docs/install\n"
  exit 1
fi
GCLOUD_VERSION="$(gcloud version 2>/dev/null | head -1 || true)"
ok "gcloud CLI: ${GCLOUD_VERSION}"

# ── jq ────────────────────────────────────────────────────────────────────────
info "Checking jq..."
if ! command -v jq >/dev/null 2>&1; then
  err "jq not found."
  printf "  Install: brew install jq (macOS) or apt-get install jq (Linux)\n"
  exit 1
fi
JQ_VERSION="$(jq --version 2>/dev/null || true)"
ok "jq: ${JQ_VERSION}"

# ── Node.js ───────────────────────────────────────────────────────────────────
info "Checking Node.js..."
if ! command -v node >/dev/null 2>&1; then
  err "Node.js not found."
  printf "  Install: https://nodejs.org/ (v20 LTS recommended)\n"
  exit 1
fi
NODE_VERSION="$(node --version 2>/dev/null || true)"
ok "Node.js: ${NODE_VERSION}"

# ── Firebase login check ─────────────────────────────────────────────────────
info "Checking Firebase authentication..."
if ! firebase projects:list --json 2>/dev/null | jq -e '.status == "success"' >/dev/null 2>&1; then
  err "Firebase CLI is not authenticated."
  printf "  Run: firebase login\n"
  exit 1
fi
ok "Firebase CLI is authenticated."

# ── gcloud login check ───────────────────────────────────────────────────────
info "Checking gcloud authentication..."
GCLOUD_ACCOUNT="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null || true)"
if [[ -z "${GCLOUD_ACCOUNT}" ]]; then
  err "gcloud is not authenticated."
  printf "  Run: gcloud auth login\n"
  exit 1
fi
ok "gcloud authenticated as: ${GCLOUD_ACCOUNT}"

printf "\n"
ok "All pre-requisites satisfied."
