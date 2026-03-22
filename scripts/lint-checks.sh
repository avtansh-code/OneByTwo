#!/usr/bin/env bash
# =============================================================================
# Custom Lint Checks — One By Two
# =============================================================================
# Run all project-specific lint checks that go beyond flutter analyze.
# Usage:  ./scripts/lint-checks.sh [--strict]
#
# Exit codes:
#   0 — all checks pass (warnings may still be printed)
#   1 — at least one hard error found
#
# Sprint 0 task: S0-08d
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Colours (disabled when not a TTY or in CI with no colour support)
# ---------------------------------------------------------------------------
if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ]; then
  RED='\033[0;31m'
  YELLOW='\033[1;33m'
  GREEN='\033[0;32m'
  CYAN='\033[0;36m'
  NC='\033[0m' # No Colour
else
  RED='' YELLOW='' GREEN='' CYAN='' NC=''
fi

STRICT=false
[ "${1:-}" = "--strict" ] && STRICT=true

ERRORS=0
WARNINGS=0

header()  { echo -e "\n${CYAN}━━━ $1 ━━━${NC}"; }
pass()    { echo -e "  ${GREEN}✅ $1${NC}"; }
fail()    { echo -e "  ${RED}❌ $1${NC}"; ERRORS=$((ERRORS + 1)); }
warn()    { echo -e "  ${YELLOW}⚠️  $1${NC}"; WARNINGS=$((WARNINGS + 1)); }

# Ensure we're running from the repo root
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

if [ ! -d "lib" ]; then
  echo -e "${RED}ERROR: lib/ directory not found. Run from project root.${NC}"
  exit 1
fi

echo -e "${CYAN}🔍 OneByTwo Custom Lint Checks${NC}"
echo "   Root: $REPO_ROOT"
echo "   Mode: $( [ "$STRICT" = true ] && echo 'strict (warnings → errors)' || echo 'normal' )"

# =============================================================================
# 1. MONEY SAFETY — no double for monetary values
# =============================================================================
header "Money Safety"

MONEY_HITS=$(grep -rn \
  "double.*amount\|double.*paise\|double.*rupee\|double.*balance\|double.*total" \
  lib/ --include="*.dart" \
  | grep -v "// display only" \
  | grep -v "_test.dart" \
  | grep -v ".g.dart" \
  | grep -v ".freezed.dart" || true)

if [ -n "$MONEY_HITS" ]; then
  if [ "$STRICT" = true ]; then
    fail "double used for money fields (use int paise instead):"
  else
    warn "Possible double used for money — review manually:"
  fi
  echo "$MONEY_HITS" | while IFS= read -r line; do
    echo "      $line"
  done
else
  pass "No double-for-money patterns detected"
fi

# =============================================================================
# 2. ARCHITECTURE COMPLIANCE
# =============================================================================
header "Architecture Compliance"

# 2a — Domain must not import Flutter / Firebase
DOMAIN_HITS=$(grep -rn \
  "import.*package:flutter\|import.*package:cloud_firestore\|import.*package:firebase" \
  lib/domain/ --include="*.dart" 2>/dev/null || true)

if [ -n "$DOMAIN_HITS" ]; then
  fail "Domain layer imports Flutter or Firebase:"
  echo "$DOMAIN_HITS" | while IFS= read -r line; do
    echo "      $line"
  done
else
  pass "Domain layer is clean (no Flutter/Firebase imports)"
fi

# 2b — Data must not import presentation
DATA_HITS=$(grep -rn \
  "import.*presentation/" \
  lib/data/ --include="*.dart" 2>/dev/null || true)

if [ -n "$DATA_HITS" ]; then
  fail "Data layer imports presentation layer:"
  echo "$DATA_HITS" | while IFS= read -r line; do
    echo "      $line"
  done
else
  pass "Data layer does not reference presentation"
fi

# 2c — Presentation should not import data directly
PRES_HITS=$(grep -rn \
  "import.*data/" \
  lib/presentation/ --include="*.dart" 2>/dev/null \
  | grep -v "// bridge ok" || true)

if [ -n "$PRES_HITS" ]; then
  warn "Presentation imports data layer directly (prefer going through domain):"
  echo "$PRES_HITS" | while IFS= read -r line; do
    echo "      $line"
  done
else
  pass "Presentation does not bypass domain layer"
fi

# =============================================================================
# 3. SECURITY CHECKS
# =============================================================================
header "Security"

# 3a — No print() in lib/
PRINT_HITS=$(grep -rn "print(" lib/ --include="*.dart" \
  | grep -v "// ignore: avoid_print" || true)

if [ -n "$PRINT_HITS" ]; then
  fail "print() found — use AppLogger instead:"
  echo "$PRINT_HITS" | while IFS= read -r line; do
    echo "      $line"
  done
else
  pass "No disallowed print() calls"
fi

# 3b — No insecure http:// URLs
HTTP_HITS=$(grep -rn "http://" lib/ --include="*.dart" \
  | grep -v "https://" \
  | grep -v "localhost" \
  | grep -v "10.0.2.2" \
  | grep -v "127.0.0.1" \
  | grep -v "// ignore" || true)

if [ -n "$HTTP_HITS" ]; then
  fail "Insecure http:// URLs found — use https://:"
  echo "$HTTP_HITS" | while IFS= read -r line; do
    echo "      $line"
  done
else
  pass "No insecure http:// URLs"
fi

# 3c — No hardcoded secrets / API keys
SECRET_HITS=$(grep -rn \
  "api_key\|apiKey\|API_KEY\|secret_key\|secretKey\|SECRET_KEY\|password.*=.*['\"]" \
  lib/ --include="*.dart" \
  | grep -v "_test.dart" \
  | grep -v ".g.dart" \
  | grep -v ".freezed.dart" \
  | grep -v "// safe" \
  | grep -v "obscureText" \
  | grep -v "labelText" \
  | grep -v "hintText" || true)

if [ -n "$SECRET_HITS" ]; then
  warn "Possible hardcoded secrets — review manually:"
  echo "$SECRET_HITS" | while IFS= read -r line; do
    echo "      $line"
  done
else
  pass "No obvious hardcoded secrets"
fi

# =============================================================================
# 4. LOCALIZATION — warn on hardcoded strings in Text() widgets
# =============================================================================
header "Localization"

# Look for Text('...') or Text("...") patterns that aren't using l10n
HARDCODED_HITS=$(grep -rn "Text(['\"]" lib/ --include="*.dart" \
  | grep -v "_test.dart" \
  | grep -v ".g.dart" \
  | grep -v ".freezed.dart" \
  | grep -v "// no-l10n" \
  | grep -v "Text('" \
  || true)

# More precise: capture Text('literal string') patterns
HARDCODED_HITS=$(grep -rEn "Text\(\s*['\"][A-Za-z]" lib/ --include="*.dart" \
  | grep -v "_test.dart" \
  | grep -v ".g.dart" \
  | grep -v ".freezed.dart" \
  | grep -v "// no-l10n" || true)

if [ -n "$HARDCODED_HITS" ]; then
  warn "Possible hardcoded strings in Text() widgets — consider using AppLocalizations:"
  echo "$HARDCODED_HITS" | head -20 | while IFS= read -r line; do
    echo "      $line"
  done
  TOTAL=$(echo "$HARDCODED_HITS" | wc -l | tr -d ' ')
  if [ "$TOTAL" -gt 20 ]; then
    echo "      ... and $((TOTAL - 20)) more"
  fi
else
  pass "No obvious hardcoded strings in Text() widgets"
fi

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo -e "${CYAN}━━━ Summary ━━━${NC}"
echo -e "  Errors:   ${RED}${ERRORS}${NC}"
echo -e "  Warnings: ${YELLOW}${WARNINGS}${NC}"
echo ""

if [ "$STRICT" = true ]; then
  TOTAL_ISSUES=$((ERRORS + WARNINGS))
else
  TOTAL_ISSUES=$ERRORS
fi

if [ "$TOTAL_ISSUES" -gt 0 ]; then
  echo -e "${RED}❌ Lint checks failed with $TOTAL_ISSUES issue(s).${NC}"
  exit 1
else
  echo -e "${GREEN}✅ All lint checks passed!${NC}"
  exit 0
fi
