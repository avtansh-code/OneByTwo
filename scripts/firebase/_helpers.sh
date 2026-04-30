#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────────────
# One By Two — Shared helpers for Firebase setup scripts
# Sourced by every script in scripts/firebase/.
# ────────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Resolve paths ─────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ARTIFACTS_DIR="${SCRIPT_DIR}/_artifacts"

# ── Load configuration ───────────────────────────────────────────────────────
CONFIG_FILE="${SCRIPT_DIR}/config.env"
if [[ ! -f "${CONFIG_FILE}" ]]; then
  printf "\033[31m✗ config.env not found at %s\033[0m\n" "${CONFIG_FILE}" >&2
  printf "  Copy config.env.example to config.env and fill in your values.\n" >&2
  exit 1
fi
# shellcheck source=/dev/null
source "${CONFIG_FILE}"

# ── Output helpers ────────────────────────────────────────────────────────────
info() { printf "\033[34mℹ %s\033[0m\n" "$1"; }
ok()   { printf "\033[32m✔ %s\033[0m\n" "$1"; }
err()  { printf "\033[31m✗ %s\033[0m\n" "$1" >&2; }
warn() { printf "\033[33m⚠ %s\033[0m\n" "$1"; }

step() {
  printf "\n\033[1m── %s ──\033[0m\n" "$1"
}

# ── Guard: ensure required variables are set ──────────────────────────────────
require_var() {
  local var_name="$1"
  if [[ -z "${!var_name:-}" ]]; then
    err "Required variable ${var_name} is not set in config.env."
    exit 1
  fi
}

# ── Ensure artifacts directory exists ─────────────────────────────────────────
mkdir -p "${ARTIFACTS_DIR}"
