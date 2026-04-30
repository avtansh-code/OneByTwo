#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────────────
# One By Two — Firebase Setup Orchestrator
# Runs all setup scripts (00 through 10) in order.
# Safe to re-run; each script is idempotent.
# ────────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()    { printf "\033[34mℹ %s\033[0m\n" "$1"; }
ok()      { printf "\033[32m✔ %s\033[0m\n" "$1"; }
err()     { printf "\033[31m✗ %s\033[0m\n" "$1" >&2; }
header()  { printf "\n\033[1;36m════════════════════════════════════════\033[0m\n"; printf "\033[1;36m  %s\033[0m\n" "$1"; printf "\033[1;36m════════════════════════════════════════\033[0m\n\n"; }

confirm() {
  local msg="$1"
  printf "\033[33m⚠ %s\033[0m\n" "${msg}"
  printf "  Continue? [y/N] "
  read -r answer
  case "${answer}" in
    [yY]|[yY][eE][sS]) return 0 ;;
    *) info "Skipped."; return 1 ;;
  esac
}

SCRIPTS=(
  "00-prereqs.sh:Check pre-requisites:false"
  "01-link-project.sh:Link Firebase project and verify billing:false"
  "02-enable-services.sh:Enable Google Cloud APIs:false"
  "03-create-firestore.sh:Create Firestore database (IRREVERSIBLE region choice):true"
  "04-create-storage.sh:Create Cloud Storage bucket:true"
  "05-deploy-rules-and-indexes.sh:Deploy Firestore/Storage rules and indexes:true"
  "06-seed-remote-config.sh:Seed Remote Config keys:true"
  "07-register-apps.sh:Register iOS and Android apps:true"
  "08-create-deployer-sa.sh:Create CI deployer service account:true"
  "09-configure-app-check.sh:Configure App Check providers:false"
  "10-smoke-test.sh:Run smoke test:false"
)

header "One By Two Firebase Setup"
info "This orchestrator runs all setup scripts in order."
info "Each script is idempotent and safe to re-run."
info "Destructive steps will prompt for confirmation."
printf "\n"

PASS_COUNT=0
SKIP_COUNT=0
FAIL_COUNT=0

for entry in "${SCRIPTS[@]}"; do
  IFS=':' read -r script_name description destructive <<< "${entry}"
  script_path="${SCRIPT_DIR}/${script_name}"

  header "${description}"

  if [[ ! -f "${script_path}" ]]; then
    err "Script not found: ${script_path}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    continue
  fi

  if [[ "${destructive}" == "true" ]]; then
    if ! confirm "This step modifies production resources: ${description}"; then
      SKIP_COUNT=$((SKIP_COUNT + 1))
      continue
    fi
  fi

  if bash "${script_path}"; then
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    err "Script '${script_name}' failed."
    printf "\n"
    printf "  You can re-run this script individually:\n"
    printf "    bash %s\n" "${script_path}"
    printf "\n"
    printf "  Or re-run this orchestrator — completed steps will be skipped.\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))

    printf "\n"
    printf "  Continue with the remaining scripts? [y/N] "
    read -r cont
    case "${cont}" in
      [yY]|[yY][eE][sS]) continue ;;
      *) break ;;
    esac
  fi
done

# ── Summary ───────────────────────────────────────────────────────────────────
header "Setup Summary"
ok "Passed:  ${PASS_COUNT}"
if [[ "${SKIP_COUNT}" -gt 0 ]]; then
  info "Skipped: ${SKIP_COUNT}"
fi
if [[ "${FAIL_COUNT}" -gt 0 ]]; then
  err "Failed:  ${FAIL_COUNT}"
  exit 1
fi

printf "\n"
ok "Firebase setup complete. Proceed to the console checklist: docs/setup/firebase-console-checklist.md"
