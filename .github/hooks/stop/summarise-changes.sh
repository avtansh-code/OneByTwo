#!/bin/sh
# ────────────────────────────────────────────────────────────────────────────────
# summarise-changes.sh
# Stop hook — prints a summary of changes made during the session when the agent
# stops, helping the user understand what was modified.
# ────────────────────────────────────────────────────────────────────────────────
set -eu

# Check if we are in a git repository.
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

# Collect staged and unstaged changes.
STAGED="$(git diff --cached --name-status 2>/dev/null || true)"
UNSTAGED="$(git diff --name-status 2>/dev/null || true)"
UNTRACKED="$(git ls-files --others --exclude-standard 2>/dev/null || true)"

# If there are no changes, say so and exit.
if [ -z "$STAGED" ] && [ -z "$UNSTAGED" ] && [ -z "$UNTRACKED" ]; then
  printf '%s\n' '--- Session Summary ---' 'No file changes detected.' '--- End Summary ---'
  exit 0
fi

printf '%s\n' '--- Session Summary ---'

if [ -n "$STAGED" ]; then
  printf '\nStaged changes:\n'
  printf '%s\n' "$STAGED" | while IFS= read -r line; do
    printf '  %s\n' "$line"
  done
fi

if [ -n "$UNSTAGED" ]; then
  printf '\nUnstaged changes:\n'
  printf '%s\n' "$UNSTAGED" | while IFS= read -r line; do
    printf '  %s\n' "$line"
  done
fi

if [ -n "$UNTRACKED" ]; then
  COUNT="$(printf '%s\n' "$UNTRACKED" | wc -l | tr -d ' ')"
  printf '\nNew files (%s):\n' "$COUNT"
  printf '%s\n' "$UNTRACKED" | while IFS= read -r line; do
    printf '  %s\n' "$line"
  done
fi

printf '\n--- End Summary ---\n'

exit 0
