#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────────────
# One By Two — 08: Create CI deployer service account
# Creates a dedicated service account for GitHub Actions deploys with minimum roles.
# Downloads the JSON key to _artifacts/ (gitignored).
# ────────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_helpers.sh"

require_var FIREBASE_PROJECT_ID
require_var DEPLOYER_SA_NAME

SA_EMAIL="${DEPLOYER_SA_NAME}@${FIREBASE_PROJECT_ID}.iam.gserviceaccount.com"
KEY_FILE="${ARTIFACTS_DIR}/${DEPLOYER_SA_NAME}.json"

step "Creating CI deployer service account: ${SA_EMAIL}"

# ── Check if service account already exists ───────────────────────────────────
info "Checking for existing service account..."
if gcloud iam service-accounts describe "${SA_EMAIL}" --project="${FIREBASE_PROJECT_ID}" >/dev/null 2>&1; then
  ok "Service account '${SA_EMAIL}' already exists. Skipping creation."
else
  info "Creating service account..."
  gcloud iam service-accounts create "${DEPLOYER_SA_NAME}" \
    --display-name="GitHub Actions Deployer" \
    --description="CI/CD service account for Firebase deployments. See docs/setup/00-decisions.md section 8." \
    --project="${FIREBASE_PROJECT_ID}" \
    --quiet
  ok "Service account '${SA_EMAIL}' created."
fi

# ── Grant IAM roles ──────────────────────────────────────────────────────────
ROLES=(
  "roles/firebase.admin"
  "roles/cloudfunctions.admin"
  "roles/firebaserules.admin"
  "roles/iam.serviceAccountUser"
)

info "Granting IAM roles..."
for role in "${ROLES[@]}"; do
  info "  Granting ${role}..."
  gcloud projects add-iam-policy-binding "${FIREBASE_PROJECT_ID}" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="${role}" \
    --condition=None \
    --quiet >/dev/null 2>&1
  ok "  ${role} granted."
done

# ── Generate JSON key ────────────────────────────────────────────────────────
if [[ -f "${KEY_FILE}" ]]; then
  warn "Key file already exists at ${KEY_FILE}. Skipping key generation."
  warn "If you need a new key, delete the existing file and re-run."
else
  info "Generating JSON key..."
  gcloud iam service-accounts keys create "${KEY_FILE}" \
    --iam-account="${SA_EMAIL}" \
    --project="${FIREBASE_PROJECT_ID}" \
    --quiet
  ok "JSON key saved to ${KEY_FILE}"
fi

# ── Instructions ──────────────────────────────────────────────────────────────
printf "\n"
ok "Deployer service account configured."
printf "\n"
info "Next steps:"
printf "  1. Upload the JSON key as the FIREBASE_SERVICE_ACCOUNT_JSON GitHub secret:\n"
printf "     gh secret set FIREBASE_SERVICE_ACCOUNT_JSON < %s\n" "${KEY_FILE}"
printf "  2. Generate a Firebase CI token and upload as FIREBASE_TOKEN:\n"
printf "     firebase login:ci\n"
printf "     gh secret set FIREBASE_TOKEN --body '<token>'\n"
printf "  3. Store the JSON key in your team vault (1Password). NEVER commit it.\n"
printf "  4. Delete the local key file once uploaded:\n"
printf "     rm %s\n" "${KEY_FILE}"
