#!/bin/sh
# ────────────────────────────────────────────────────────────────────────────────
# One By Two — Start Firebase Emulator Suite
# POSIX-compatible script for local development.
#
# Usage:
#   ./scripts/dev/start-emulators.sh
#   ./scripts/dev/start-emulators.sh --import=./firebase-export
#   ./scripts/dev/start-emulators.sh --project demo-onebytwo   # explicit override
#
# Emulators started: Auth (9099), Firestore (8181), Functions (5001),
#                    Storage (9199), UI (4000)
#
# Project ID is read from .firebaserc (Invariant #4: single Firebase project).
# The Flutter app's Firebase config uses the production project ID, so emulators
# must be started with that same project ID for the Emulator UI to display
# documents correctly.
# ────────────────────────────────────────────────────────────────────────────────
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ── Resolve project ID from .firebaserc ──────────────────────────────────────

FIREBASERC="${PROJECT_ROOT}/.firebaserc"

if [ ! -f "$FIREBASERC" ]; then
  echo "ERROR: .firebaserc not found at ${FIREBASERC}" >&2
  echo "       Cannot determine the Firebase project ID." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is not installed." >&2
  echo "       Install it via: brew install jq  (macOS) or apt-get install jq (Linux)" >&2
  exit 1
fi

PROJECT_ID="$(jq -r '.projects.default // empty' "$FIREBASERC")"

if [ -z "$PROJECT_ID" ]; then
  echo "ERROR: .projects.default is missing or empty in ${FIREBASERC}" >&2
  exit 1
fi

# Reject demo-* project IDs read from .firebaserc (likely misconfiguration).
case "$PROJECT_ID" in
  demo-*)
    echo "ERROR: .firebaserc contains a demo-* project ID (${PROJECT_ID})." >&2
    echo "       Invariant #4 requires the production project ID in .firebaserc." >&2
    echo "       If you need demo-* for isolated testing, pass --project demo-* explicitly." >&2
    exit 1
    ;;
esac

# ── Parse arguments ──────────────────────────────────────────────────────────

# Default seed data path (can be overridden via --import=<path>).
SEED_DATA_PATH="${PROJECT_ROOT}/firebase-export"
IMPORT_FLAG=""

if [ -d "$SEED_DATA_PATH" ]; then
  IMPORT_FLAG="--import=$SEED_DATA_PATH"
fi

EXPLICIT_PROJECT=""
EXTRA_ARGS=""

for arg in "$@"; do
  case "$arg" in
    --import=*)
      IMPORT_FLAG="$arg"
      ;;
    --project)
      # Handle --project <value> (next iteration picks up the value via shift
      # workaround below). For simplicity we support --project=<value> form.
      ;;
    --project=*)
      EXPLICIT_PROJECT="${arg#--project=}"
      ;;
    *)
      EXTRA_ARGS="${EXTRA_ARGS} ${arg}"
      ;;
  esac
done

# Support bare --project <value> (two separate args).
PREV=""
for arg in "$@"; do
  if [ "$PREV" = "--project" ]; then
    EXPLICIT_PROJECT="$arg"
  fi
  PREV="$arg"
done

# If an explicit --project was provided, use it (with a warning for demo-*).
if [ -n "$EXPLICIT_PROJECT" ]; then
  case "$EXPLICIT_PROJECT" in
    demo-*)
      echo "WARNING: Using demo-* project ID via explicit override." >&2
      echo "         Firebase demo-* projects run fully offline emulators." >&2
      echo "         This is intentional only for isolated testing." >&2
      ;;
  esac
  PROJECT_ID="$EXPLICIT_PROJECT"
fi

# ── Start emulators ──────────────────────────────────────────────────────────

echo "Starting Firebase Emulator Suite..."
echo "Project root: $PROJECT_ROOT"
echo "Project ID:   $PROJECT_ID"
echo "Import flag:  ${IMPORT_FLAG:-<none>}"

cd "$PROJECT_ROOT"

# Build Cloud Functions before starting emulators.
if [ -f "functions/package.json" ]; then
  echo "Building Cloud Functions..."
  (cd functions && npm run build)
fi

# Start emulators with the resolved project ID so the Emulator UI aligns
# with the Flutter app. All traffic stays local via useXxxEmulator() calls.
# shellcheck disable=SC2086
firebase emulators:start \
  --only auth,firestore,functions,storage \
  --project "$PROJECT_ID" \
  $IMPORT_FLAG $EXTRA_ARGS
