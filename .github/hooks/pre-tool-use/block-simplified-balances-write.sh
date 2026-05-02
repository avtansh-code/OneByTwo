#!/bin/sh
# ────────────────────────────────────────────────────────────────────────────────
# block-simplified-balances-write.sh
# PreToolUse hook — prevents client-side writes to the simplifiedBalances field.
#
# Invariant 2: simplifiedBalances is server-maintained and client-read-only.
# Only the recomputeSimplifiedBalances Cloud Function may write this field.
# SRS sections: 4.6, 7.3, 7.5
# ────────────────────────────────────────────────────────────────────────────────
set -eu

# This hook receives the tool input via stdin. Read it.
INPUT="$(cat)"

# Extract the file path from the input if available.
# Use jq for reliable JSON parsing; fall back to regex if jq is unavailable.
if command -v jq >/dev/null 2>&1; then
  FILE_PATH="$(printf '%s' "$INPUT" | jq -r '.file_path // .path // empty' 2>/dev/null || true)"
else
  FILE_PATH="$(printf '%s' "$INPUT" | grep -oE '"(file_path|path)"\s*:\s*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//' || true)"
fi

# Log invocation for audit trail.
printf '[hook] block-simplified-balances-write: checking %s\n' "${FILE_PATH:-<unknown>}" >&2

# Only check files under lib/ (client code).
case "$FILE_PATH" in
  lib/*)
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

# Check for writes to simplifiedBalances from client code.
if printf '%s' "$CONTENT" | grep -qiE "simplifiedBalances|simplified_balances"; then
  # Allow reads (watching, listening, reading the field).
  if printf '%s' "$CONTENT" | grep -qiE '\.set\(|\.update\(|\.write|\.batch|\.commit|\.runTransaction'; then
    printf 'BLOCKED: Client-side write to simplifiedBalances detected in %s.\n' "$FILE_PATH" >&2
    printf 'Invariant 2 (SRS sections 4.6, 7.3, 7.5): simplifiedBalances is\n' >&2
    printf 'server-maintained and client-read-only. Only the Cloud Function\n' >&2
    printf 'recomputeSimplifiedBalances may write this field.\n' >&2
    exit 1
  fi
fi

exit 0
