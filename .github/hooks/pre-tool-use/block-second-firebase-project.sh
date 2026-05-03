#!/bin/sh
# ────────────────────────────────────────────────────────────────────────────────
# block-second-firebase-project.sh
# PreToolUse hook — prevents introduction of a second Firebase project ID.
#
# Invariant 4: Single Firebase project. No staging or dev projects.
# SRS sections: 3.4, 9.1
#
# Checks:
#   1. Firebase config files (.firebaserc, firebase.json) for staging/dev aliases.
#   2. Shell scripts (scripts/**/*.sh) for firebase CLI invocations missing
#      --project flag. Excludes scripts/dev/start-emulators.sh (canonical wrapper).
#   3. GitHub Actions workflows (.github/workflows/*.yml) for firebase CLI
#      invocations missing --project flag.
# ────────────────────────────────────────────────────────────────────────────────
set -eu

INPUT="$(cat)"

# Extract the file path.
# Use jq for reliable JSON parsing; fall back to regex if jq is unavailable.
if command -v jq >/dev/null 2>&1; then
  FILE_PATH="$(printf '%s' "$INPUT" | jq -r '.file_path // .path // empty' 2>/dev/null || true)"
else
  FILE_PATH="$(printf '%s' "$INPUT" | grep -oE '"(file_path|path)"\s*:\s*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//' || true)"
fi

# Log invocation for audit trail.
printf '[hook] block-second-firebase-project: checking %s\n' "${FILE_PATH:-<unknown>}" >&2

# Only check files where Firebase project IDs could be introduced.
case "$FILE_PATH" in
  firebase.json|.firebaserc|*.yaml|*.yml|*.json)
    ;;
  *.sh)
    ;;
  *)
    exit 0
    ;;
esac

# Extract the content being written.
# Use jq for reliable JSON parsing; fall back to regex if jq is unavailable.
if command -v jq >/dev/null 2>&1; then
  CONTENT="$(printf '%s' "$INPUT" | jq -r '.new_str // .content // .file_text // empty' 2>/dev/null || true)"
else
  CONTENT="$(printf '%s' "$INPUT" | grep -oE '"(new_str|content|file_text)"\s*:\s*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//' || true)"
fi

if [ -z "$CONTENT" ]; then
  CONTENT="$INPUT"
fi

# Check for patterns that suggest a second Firebase project.
# Look for staging/dev project patterns in Firebase config files.
# NOTE: Uses ERE (-E) so alternation is | not \|.
STAGING_PATTERNS='staging|development|dev-project|stg-project|"dev"|"staging"|"test-project"'

# Helper: print the invariant violation message.
block_message() {
  _FILE="$1"
  _REASON="$2"
  printf 'BLOCKED: %s in %s.\n' "$_REASON" "$_FILE" >&2
  printf 'Invariant 4 (SRS sections 3.4, 9.1): There is exactly one Firebase\n' >&2
  printf 'project (production). No staging or development projects are permitted.\n' >&2
  printf 'Use the Firebase Emulator Suite for all non-production testing.\n' >&2
}

case "$FILE_PATH" in
  .firebaserc)
    # In .firebaserc, multiple project aliases indicate multiple projects.
    if printf '%s' "$CONTENT" | grep -qiE "$STAGING_PATTERNS"; then
      block_message "$FILE_PATH" "Second Firebase project alias detected"
      exit 1
    fi
    ;;
  firebase.json)
    if printf '%s' "$CONTENT" | grep -qiE "$STAGING_PATTERNS"; then
      block_message "$FILE_PATH" "Staging/dev Firebase configuration detected"
      exit 1
    fi
    ;;
  *.sh)
    # Check shell scripts for firebase CLI invocations missing --project.
    # Exclude the canonical emulator wrapper — it reads .firebaserc internally.
    case "$FILE_PATH" in
      scripts/dev/start-emulators.sh|*/scripts/dev/start-emulators.sh)
        # Canonical wrapper: skip this check.
        ;;
      *)
        # Does the content invoke firebase emulators:start or firebase deploy?
        if printf '%s' "$CONTENT" | grep -qE 'firebase (emulators:start|emulators:exec|deploy)'; then
          # Verify --project is present somewhere in the content.
          if ! printf '%s' "$CONTENT" | grep -qE -- '--project'; then
            block_message "$FILE_PATH" "firebase CLI invocation without --project flag"
            printf 'All firebase CLI calls must include --project to enforce the\n' >&2
            printf 'correct project ID. Use scripts/dev/start-emulators.sh for\n' >&2
            printf 'local emulator usage, or pass --project explicitly.\n' >&2
            exit 1
          fi
        fi
        ;;
    esac
    ;;
  *.yaml|*.yml)
    # In workflow files, check for staging project references.
    if printf '%s' "$CONTENT" | grep -qiE 'FIREBASE.*PROJECT.*ID.*staging|firebase.*deploy.*--project.*staging|firebase.*use.*staging'; then
      block_message "$FILE_PATH" "Second Firebase project reference detected"
      exit 1
    fi
    # Also check for firebase CLI invocations without --project.
    if printf '%s' "$CONTENT" | grep -qE 'firebase (emulators:start|emulators:exec|deploy)'; then
      if ! printf '%s' "$CONTENT" | grep -qE -- '--project'; then
        block_message "$FILE_PATH" "firebase CLI invocation without --project flag"
        printf 'All firebase CLI calls in workflow files must include --project\n' >&2
        printf 'to enforce the correct project ID.\n' >&2
        exit 1
      fi
    fi
    ;;
esac

exit 0
