#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────────────
# One By Two — Upload GitHub Actions secrets from a local .secrets/ directory
#
# Reads credential files from .secrets/ (gitignored) and uploads each one as a
# GitHub Actions repository secret using the `gh` CLI.
#
# Usage:
#   bash scripts/stores/upload-github-secrets.sh
#
# Pre-requisites:
#   - `gh` CLI installed and authenticated (`gh auth login`)
#   - .secrets/ directory exists at the repo root with one file per secret
#   - Each filename matches the secret name exactly (see manifest below)
#
# This script NEVER prints secret values to stdout.
# ────────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SECRETS_DIR="${REPO_ROOT}/.secrets"

info() { printf "\033[34mℹ %s\033[0m\n" "$1"; }
ok()   { printf "\033[32m✔ %s\033[0m\n" "$1"; }
err()  { printf "\033[31m✗ %s\033[0m\n" "$1" >&2; }
warn() { printf "\033[33m⚠ %s\033[0m\n" "$1"; }

# ── Pre-flight checks ────────────────────────────────────────────────────────
if ! command -v gh >/dev/null 2>&1; then
  err "GitHub CLI (gh) not found."
  printf "  Install: https://cli.github.com/\n"
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  err "GitHub CLI is not authenticated."
  printf "  Run: gh auth login\n"
  exit 1
fi

if [[ ! -d "${SECRETS_DIR}" ]]; then
  err ".secrets/ directory not found at ${SECRETS_DIR}"
  printf "  Create it and add one file per secret:\n"
  printf "    mkdir -p .secrets\n"
  printf "    echo '<value>' > .secrets/FIREBASE_TOKEN\n"
  exit 1
fi

# ── Secret manifest (SRS section 9.3) ────────────────────────────────────────
# Every secret name that must exist. Files that are binary should already be
# base64-encoded by the user (the filename should still match the secret name).
REQUIRED_SECRETS=(
  "FIREBASE_SERVICE_ACCOUNT_JSON"
  "ANDROID_KEYSTORE_BASE64"
  "ANDROID_KEYSTORE_PASSWORD"
  "KEY_ALIAS"
  "KEY_PASSWORD"
  "PLAY_SERVICE_ACCOUNT_JSON"
  "APP_STORE_CONNECT_API_KEY_ID"
  "ISSUER_ID"
  "KEY_BASE64"
  "MATCH_GIT_URL"
  "MATCH_PASSWORD"
)

# ── Validate all secrets are present ──────────────────────────────────────────
info "Validating .secrets/ directory..."
MISSING=()
for secret_name in "${REQUIRED_SECRETS[@]}"; do
  if [[ ! -f "${SECRETS_DIR}/${secret_name}" ]]; then
    MISSING+=("${secret_name}")
  fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
  err "Missing secret files in .secrets/:"
  for m in "${MISSING[@]}"; do
    printf "    - %s\n" "${m}"
  done
  printf "\n"
  printf "  Each secret must be a file named exactly as shown above.\n"
  printf "  See docs/setup/secrets-manifest.md for the source of each credential.\n"
  printf "\n"
  printf "  Continue uploading the secrets that ARE present? [y/N] "
  read -r answer
  case "${answer}" in
    [yY]|[yY][eE][sS]) warn "Proceeding with partial upload." ;;
    *) info "Aborted."; exit 1 ;;
  esac
fi

# ── Upload secrets ────────────────────────────────────────────────────────────
UPLOAD_COUNT=0
FAIL_COUNT=0

for secret_name in "${REQUIRED_SECRETS[@]}"; do
  secret_file="${SECRETS_DIR}/${secret_name}"
  if [[ ! -f "${secret_file}" ]]; then
    continue
  fi

  info "Uploading ${secret_name}..."
  if gh secret set "${secret_name}" < "${secret_file}" 2>/dev/null; then
    ok "${secret_name} uploaded."
    UPLOAD_COUNT=$((UPLOAD_COUNT + 1))
  else
    err "Failed to upload ${secret_name}."
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
done

# ── Summary ───────────────────────────────────────────────────────────────────
printf "\n"
ok "Uploaded: ${UPLOAD_COUNT} secret(s)."
if [[ ${#MISSING[@]} -gt 0 ]]; then
  warn "Skipped:  ${#MISSING[@]} missing secret(s)."
fi
if [[ "${FAIL_COUNT}" -gt 0 ]]; then
  err "Failed:   ${FAIL_COUNT} secret(s)."
  exit 1
fi

printf "\n"
info "Next steps:"
printf "  1. Verify secrets in GitHub: Settings → Secrets and variables → Actions\n"
printf "  2. Delete the local .secrets/ directory:\n"
printf "     rm -rf %s\n" "${SECRETS_DIR}"
printf "  3. Store all raw credential files in 1Password (team vault).\n"
