#!/bin/sh
# ────────────────────────────────────────────────────────────────────────────────
# dart-format.sh
# PostToolUse hook — runs dart format on Dart files after edits.
# ────────────────────────────────────────────────────────────────────────────────
set -eu

INPUT="$(cat)"

# Extract the file path.
FILE_PATH="$(printf '%s' "$INPUT" | grep -oE '"(file_path|path)"\s*:\s*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//' || true)"

# Only format Dart files.
case "$FILE_PATH" in
  *.dart)
    ;;
  *)
    exit 0
    ;;
esac

# Check that the file exists.
if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# Check that dart is available.
if ! command -v dart >/dev/null 2>&1; then
  # Try via flutter.
  if command -v flutter >/dev/null 2>&1; then
    flutter format --fix "$FILE_PATH" 2>/dev/null || true
  fi
  exit 0
fi

dart format --fix "$FILE_PATH" 2>/dev/null || true

exit 0
