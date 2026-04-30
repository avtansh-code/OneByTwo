#!/bin/sh
# ────────────────────────────────────────────────────────────────────────────────
# load-srs-context.sh
# UserPromptSubmit hook — prints a short context reminder pointing the agent to
# the SRS, invariants, and shared context files at the start of every session.
# ────────────────────────────────────────────────────────────────────────────────
set -eu

SRS_PATH="docs/OneByTwo_Requirements_Spec.md"
INVARIANTS_PATH=".github/shared/invariants.md"
GLOSSARY_PATH=".github/shared/glossary.md"

cat <<EOF
--- OneByTwo Context ---
Product: OneByTwo — India-focused expense-sharing app (Flutter + Firebase).
SRS: ${SRS_PATH} (v1.1, approved baseline).

Invariants (non-negotiable):
  1. Money is integer paise (1 INR = 100 paise). Never floats.
  2. simplifiedBalances is server-maintained, client-read-only.
  3. System share sheet only. No platform-specific share targets.
  4. Single Firebase project. No staging/dev projects. Emulator Suite for testing.

Shared context: .github/shared/
Agents: .github/agents/ (delegate to orchestrator for non-trivial tasks).
Skills: .github/skills/
--- End Context ---
EOF

exit 0
