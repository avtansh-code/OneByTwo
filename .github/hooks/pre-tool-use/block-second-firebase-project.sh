#!/bin/sh
# ────────────────────────────────────────────────────────────────────────────────
# block-second-firebase-project.sh
# PreToolUse hook — prevents introduction of a second Firebase project ID.
#
# Invariant 4: Single Firebase project. No staging or dev projects.
# SRS sections: 3.4, 9.1
# ────────────────────────────────────────────────────────────────────────────────
set -eu

INPUT="$(cat)"

# Extract the file path.
FILE_PATH="$(printf '%s' "$INPUT" | grep -oE '"(file_path|path)"\s*:\s*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//' || true)"

# Log invocation for audit trail.
printf '[hook] block-second-firebase-project: checking %s\n' "${FILE_PATH:-<unknown>}" >&2

# Only check files where Firebase project IDs could be introduced.
case "$FILE_PATH" in
  firebase.json|.firebaserc|*.yaml|*.yml|*.json)
    ;;
  *)
    exit 0
    ;;
esac

# Extract the content being written.
CONTENT="$(printf '%s' "$INPUT" | grep -oE '"(new_str|content|file_text)"\s*:\s*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//' || true)"

if [ -z "$CONTENT" ]; then
  CONTENT="$INPUT"
fi

# Check for patterns that suggest a second Firebase project.
# Look for staging/dev project patterns in Firebase config files.
STAGING_PATTERNS='staging\|development\|dev-project\|stg-project\|"dev"\|"staging"\|"test-project"'

case "$FILE_PATH" in
  .firebaserc)
    # In .firebaserc, multiple project aliases indicate multiple projects.
    if printf '%s' "$CONTENT" | grep -qiE "$STAGING_PATTERNS"; then
      printf 'BLOCKED: Second Firebase project alias detected in %s.\n' "$FILE_PATH" >&2
      printf 'Invariant 4 (SRS sections 3.4, 9.1): There is exactly one Firebase\n' >&2
      printf 'project (production). No staging or development projects are permitted.\n' >&2
      printf 'Use the Firebase Emulator Suite for all non-production testing.\n' >&2
      exit 1
    fi
    ;;
  firebase.json)
    if printf '%s' "$CONTENT" | grep -qiE "$STAGING_PATTERNS"; then
      printf 'BLOCKED: Staging/dev Firebase configuration detected in %s.\n' "$FILE_PATH" >&2
      printf 'Invariant 4 (SRS sections 3.4, 9.1): There is exactly one Firebase\n' >&2
      printf 'project (production). No staging or development projects are permitted.\n' >&2
      printf 'Use the Firebase Emulator Suite for all non-production testing.\n' >&2
      exit 1
    fi
    ;;
  *.yaml|*.yml)
    # In workflow files, check for multiple Firebase project references.
    if printf '%s' "$CONTENT" | grep -qiE 'FIREBASE.*PROJECT.*ID.*staging\|firebase.*deploy.*--project.*staging\|firebase.*use.*staging'; then
      printf 'BLOCKED: Second Firebase project reference detected in %s.\n' "$FILE_PATH" >&2
      printf 'Invariant 4 (SRS sections 3.4, 9.1): There is exactly one Firebase\n' >&2
      printf 'project (production). No staging or development projects are permitted.\n' >&2
      printf 'Use the Firebase Emulator Suite for all non-production testing.\n' >&2
      exit 1
    fi
    ;;
esac

exit 0
