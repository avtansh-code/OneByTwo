#!/bin/sh
# ────────────────────────────────────────────────────────────────────────────────
# One By Two — Start Firebase Emulator Suite
# POSIX-compatible script for local development.
#
# Usage:
#   ./scripts/dev/start-emulators.sh
#   ./scripts/dev/start-emulators.sh --import=./firebase-export
#
# Emulators started: Auth (9099), Firestore (8181), Functions (5001),
#                    Storage (9199), UI (4000)
# Project ID: demo-onebytwo (offline-only demo project — Invariant 4)
# ────────────────────────────────────────────────────────────────────────────────
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Default seed data path (can be overridden via --import=<path>).
SEED_DATA_PATH="${PROJECT_ROOT}/firebase-export"
IMPORT_FLAG=""

if [ -d "$SEED_DATA_PATH" ]; then
  IMPORT_FLAG="--import=$SEED_DATA_PATH"
fi

# Parse arguments — pass through to firebase emulators:start.
for arg in "$@"; do
  case "$arg" in
    --import=*)
      IMPORT_FLAG="$arg"
      ;;
  esac
done

echo "Starting Firebase Emulator Suite..."
echo "Project root: $PROJECT_ROOT"
echo "Import flag:  ${IMPORT_FLAG:-<none>}"

cd "$PROJECT_ROOT"

# Build Cloud Functions before starting emulators.
if [ -f "functions/package.json" ]; then
  echo "Building Cloud Functions..."
  (cd functions && npm run build)
fi

# Start emulators with the demo project ID (no production credentials needed).
# shellcheck disable=SC2086
firebase emulators:start \
  --only auth,firestore,functions,storage \
  --project demo-onebytwo \
  $IMPORT_FLAG
