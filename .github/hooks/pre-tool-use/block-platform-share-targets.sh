#!/bin/sh
# ────────────────────────────────────────────────────────────────────────────────
# block-platform-share-targets.sh
# PreToolUse hook — prevents imports of platform-specific share packages.
#
# Invariant 3: System share sheet only. No platform-specific share targets.
# SRS sections: 3.4, 4.11, 12.2
# ────────────────────────────────────────────────────────────────────────────────
set -eu

INPUT="$(cat)"

# Extract the file path.
FILE_PATH="$(printf '%s' "$INPUT" | grep -oE '"(file_path|path)"\s*:\s*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//' || true)"

# Log invocation for audit trail.
printf '[hook] block-platform-share-targets: checking %s\n' "${FILE_PATH:-<unknown>}" >&2

# Only check Dart and YAML files (source code and pubspec).
case "$FILE_PATH" in
  *.dart|*.yaml|*.yml)
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

# Blocklist: package names or imports that target a specific messaging platform.
BLOCKED_PATTERNS='whatsapp_share\|wa_share\|whatsapp_unilink\|telegram_share\|telegram_bot\|facebook_share\|fb_share\|instagram_share\|line_share\|viber_share\|signal_share\|wechat_share'

if printf '%s' "$CONTENT" | grep -qi "$BLOCKED_PATTERNS"; then
  MATCHED="$(printf '%s' "$CONTENT" | grep -oi "$BLOCKED_PATTERNS" | head -1)"
  printf 'BLOCKED: Platform-specific share package detected: %s\n' "$MATCHED" >&2
  printf 'Invariant 3 (SRS sections 3.4, 4.11, 12.2): All outbound sharing must\n' >&2
  printf 'use the system share sheet. The app must not target, deep-link to, or\n' >&2
  printf 'import packages for any specific messaging app.\n' >&2
  printf 'Use share_plus or the platform-native share API instead.\n' >&2
  exit 1
fi

exit 0
