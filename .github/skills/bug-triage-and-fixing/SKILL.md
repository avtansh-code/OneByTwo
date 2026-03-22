---
name: bug-triage-and-fixing
description: "Systematic bug triage methodology — severity classification, reproduction template, root cause analysis, fix verification, and regression test requirements for the One By Two app."
---

# Bug Triage and Fixing

Systematic methodology for triaging, diagnosing, fixing, and verifying bugs in the **One By Two** Flutter + Firebase expense splitting app. This goes beyond fixing individual bugs — it provides a repeatable process for severity classification, root cause analysis, fix verification, and regression prevention.

---

## 1. Bug Severity Classification

| Severity | Definition | Response Time | Examples |
|----------|-----------|---------------|----------|
| **P0 — Critical** | App crash, data loss, money calculation wrong, security breach | Fix immediately, hotfix release | Split amounts don't sum to total, balance shows wrong amount, auth bypass |
| **P1 — High** | Feature broken, major UX broken, data inconsistency | Fix within 24 hours | Expense not saving, sync stuck, notification not delivered |
| **P2 — Medium** | Feature partially broken, workaround exists | Fix within sprint | Filter not working, search returns wrong results, minor UI glitch |
| **P3 — Low** | Cosmetic, minor inconvenience | Backlog | Text truncation, animation glitch, non-critical tooltip wrong |

### P0 Auto-Triggers for One By Two

These are **always P0** regardless of other context:

- Any bug where `double` is used for money (always P0)
- Any bug where split sum ≠ total (always P0)
- Any bug where balance is calculated incorrectly (always P0)
- Any security rule that allows unauthorized access (always P0)
- Any bug that causes data loss (always P0)

---

## 2. Bug Report Template

Use this template for every bug report to ensure consistent, actionable information:

```markdown
## Bug Report

**Title:** [Concise description]
**Severity:** P0 / P1 / P2 / P3
**Reporter:** [Name]
**Date:** [YYYY-MM-DD]

### Environment
- App version: [e.g., 1.2.3+42]
- Device: [e.g., Pixel 8, iPhone 15]
- OS: [e.g., Android 15, iOS 17.4]
- Network: [Online / Offline / Intermittent]

### Steps to Reproduce
1. [Step 1]
2. [Step 2]
3. [Step 3]

### Expected Behavior
[What should happen]

### Actual Behavior
[What actually happens]

### Evidence
- Screenshot/recording: [attach]
- Crash log: [attach]
- Exported app logs: [attach if available]

### Additional Context
- Does it happen offline? [Yes/No]
- Does it happen consistently? [Always / Sometimes / Once]
- Related recent changes: [PR/commit if known]
```

---

## 3. Root Cause Analysis (RCA) Methodology

Follow these five steps in order. Do not skip steps — each one narrows the search space.

```text
STEP 1: REPRODUCE
  ├── Create a failing test that demonstrates the bug
  ├── If cannot reproduce → ask for more details, check logs
  └── Document exact reproduction steps

STEP 2: ISOLATE
  ├── Which layer? UI → Provider → Use Case → Repository → Firestore
  ├── Binary search: Is the data wrong in Firestore? In the model? In the entity?
  ├── Check: Is it a client bug or Cloud Function bug?
  └── Check: Does it only happen offline? Only after sync?

STEP 3: TRACE DATA FLOW
  For money/balance bugs:
  ├── What is the expense amount (paise)?
  ├── What split type and how many participants?
  ├── What does the split algorithm return?
  ├── What gets written to Firestore (splits subcollection)?
  ├── What does the Cloud Function calculate for balances?
  └── What does the UI display?

  For sync bugs:
  ├── What does the local cache show?
  ├── What does the server show?
  ├── Is hasPendingWrites true or false?
  ├── Are there pending writes in the SDK queue?
  └── Did the Cloud Function trigger fire?

STEP 4: IDENTIFY ROOT CAUSE
  ├── The specific line(s) of code causing the issue
  ├── Why the existing tests didn't catch it
  └── What conditions trigger it (edge case, race condition, etc.)

STEP 5: CLASSIFY ROOT CAUSE
  ├── Logic error (wrong algorithm/formula)
  ├── Type error (double vs int for money)
  ├── State management (stale data, missing rebuild)
  ├── Race condition (async timing)
  ├── Missing validation (input not checked)
  ├── Security rule gap (access not denied)
  └── Configuration (wrong region, missing index)
```

---

## 4. Fix Verification Process

Before merging a bug fix, verify **all** of these:

```text
[ ] Regression test written and passing
    → Test named: test('regression: BUG-{id} — {description}')
    → Test proves the fix (would fail without the fix)

[ ] Existing tests still passing
    → flutter test (all green)
    → flutter analyze (zero issues)

[ ] Money integrity preserved (if money-related bug)
    → sum(splits) == total for all affected scenarios
    → No double used for amounts

[ ] Offline behavior preserved
    → Fix works when offline
    → Sync still works after fix

[ ] No side effects
    → Related features still work
    → Performance not degraded

[ ] PR created with:
    → Bug ID in title: "fix(scope): BUG-{id} description"
    → Root cause explanation in PR body
    → Link to regression test
    → Before/after evidence
```

---

## 5. Common Bug Patterns in One By Two

These are the most likely bug patterns in an expense splitting app. When triaging, check these first.

### Pattern 1: Money Rounding Error

- **Symptom:** Balance off by 1–2 paise
- **Root cause:** Integer division without remainder distribution
- **Fix:** Use Largest Remainder Method — distribute remainder 1 paise at a time to participants
- **Regression test:** Split odd amounts by prime numbers (e.g., 1000 paise ÷ 3 people → 334 + 333 + 333 = 1000)

### Pattern 2: Stale Balance After Delete

- **Symptom:** Balance doesn't update after deleting an expense
- **Root cause:** `onExpenseDeleted` Cloud Function trigger not recalculating group/friend balances
- **Fix:** Ensure soft-delete triggers balance recalculation via the Cloud Function
- **Regression test:** Delete expense → verify balance updated for all affected users

### Pattern 3: Duplicate Expense After Sync

- **Symptom:** Same expense appears twice after coming back online
- **Root cause:** Client retried write after timeout, server received it twice
- **Fix:** Use client-generated UUID as the document ID (idempotent writes)
- **Regression test:** Write same document ID twice → verify only one document exists in Firestore

### Pattern 4: Friend Balance Sign Flipped

- **Symptom:** Shows "you owe ₹500" instead of "you are owed ₹500"
- **Root cause:** Canonical pair ordering (`min`/`max` of user IDs) not applied consistently
- **Fix:** Always use `min(a, b)_max(a, b)` for the pair ID; define a consistent sign convention
- **Regression test:** Check balance from both user perspectives — signs must be opposite

### Pattern 5: Widget Not Rebuilding

- **Symptom:** UI shows old data after a mutation (add/edit/delete expense)
- **Root cause:** Riverpod provider not invalidated or refreshed after the write operation
- **Fix:** Invalidate or refresh the correct provider after every mutation in the use case or controller
- **Regression test:** Widget test — mutate data → `await tester.pump()` → verify UI reflects update

---

## 6. Hotfix Workflow (P0 Bugs)

For critical bugs that need an immediate production fix:

```text
1. Create branch: hotfix/BUG-{id}-{description}
2. Write regression test (RED — test fails without fix)
3. Implement minimal fix (GREEN — test passes)
4. Run full test suite
5. Create PR targeting main
6. Fast-track review (1 reviewer, skip non-critical checks)
7. Merge and tag: v{major}.{minor}.{patch+1}
8. Deploy immediately via release pipeline
9. Monitor Crashlytics for 1 hour post-deploy
```
