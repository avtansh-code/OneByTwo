#!/bin/sh
# ────────────────────────────────────────────────────────────────────────────────
# eslint-fix.sh
# PostToolUse hook — runs ESLint auto-fix on TypeScript/JavaScript files in
# the functions/ directory after edits.
# ────────────────────────────────────────────────────────────────────────────────
set -eu

INPUT="$(cat)"

# Extract the file path.
FILE_PATH="$(printf '%s' "$INPUT" | grep -oE '"(file_path|path)"\s*:\s*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//' || true)"

# Log invocation for audit trail.
printf '[hook] eslint-fix: checking %s\n' "${FILE_PATH:-<unknown>}" >&2

# Only lint TypeScript/JavaScript files under functions/.
case "$FILE_PATH" in
  functions/*.ts|functions/*.js)
    ;;
  *)
    exit 0
    ;;
esac

# Check that the file exists.
if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# Check that npx is available and eslint is installed.
if ! command -v npx >/dev/null 2>&1; then
  exit 0
fi

# Run ESLint auto-fix from the functions directory.
FUNCTIONS_DIR="$(dirname "$FILE_PATH")"
# Walk up to find the functions/ root.
while [ "$(basename "$FUNCTIONS_DIR")" != "functions" ] && [ "$FUNCTIONS_DIR" != "/" ]; do
  FUNCTIONS_DIR="$(dirname "$FUNCTIONS_DIR")"
done

if [ -d "$FUNCTIONS_DIR/node_modules" ]; then
  (cd "$FUNCTIONS_DIR" && npx eslint --fix "$FILE_PATH" 2>/dev/null) || true
fi

exit 0
