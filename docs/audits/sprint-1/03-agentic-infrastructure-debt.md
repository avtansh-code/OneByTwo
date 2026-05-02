# Phase 3 — Agentic Infrastructure Debt Review

**Date:** 2026-05-02
**Lead:** Architect
**Consulting:** DevOps

---

## 3.1 Hook Firing Audit

### PreToolUse Hooks

| # | Hook | Finding | Severity | Action | Owner |
|---|---|---|---|---|---|
| H1 | `block-second-firebase-project.sh` | **JSON extraction fragility.** The regex-based content extraction may fail to detect staging/dev project IDs when the tool input JSON contains escaped quotes or multiline content. This means a write adding a second Firebase project in `.firebaserc` could pass the hook if the JSON structure is complex enough. This is the only enforcement layer for Invariant 4. | **High** | **Fix now** — replace regex-based JSON extraction with `jq`-based parsing across all three PreToolUse hooks. Add a unit test for the hook itself (input with escaped quotes containing a second project ID must be blocked). | DevOps |
| H2 | `block-simplified-balances-write.sh` | **Working correctly.** Blocks client-side (`lib/`) writes containing `simplifiedBalances`. Allows server-side (`functions/`) writes. The JSON extraction fragility (H1) applies here too, but the hook has not produced false negatives in practice because the string `simplifiedBalances` is distinctive enough that partial extraction still catches it. | Low | Fix now — addressed by the unified `jq` fix in H1. No separate action needed. | DevOps |
| H3 | `block-platform-share-targets.sh` | **Working correctly.** Blocks imports of WhatsApp, Telegram, and other platform-specific share packages. Same JSON fragility caveat as H1/H2. No false negatives observed — Sprint 1 did not introduce share functionality, so the hook was not exercised under real conditions. | Low | Fix now — addressed by H1. Will be fully exercised in Sprint 2+ when sharing features are implemented. | DevOps |

### PostToolUse Hooks

| # | Hook | Finding | Severity | Action | Owner |
|---|---|---|---|---|---|
| H4 | `dart-format.sh` | **Working as expected.** Runs `dart format` on edited `.dart` files. No consistent failures or silent skips reported during Sprint 1. | — | None | — |
| H5 | `eslint-fix.sh` | **Working as expected.** Runs ESLint auto-fix on edited `.ts` files under `functions/`. No issues reported. | — | None | — |

### Hook False Positives / False Negatives

| Type | Count | Details |
|---|---|---|
| Confirmed false positives | 0 | No reports of hooks blocking legitimate work. |
| Confirmed false negatives | 0 | No invariant violations slipped through during Sprint 1. |
| Potential false negatives | 1 | H1 — JSON extraction fragility could allow a second Firebase project to pass if the content structure is complex. Not triggered in practice. |

---

## 3.2 Agent Description Accuracy

| # | Agent | Finding | Severity | Action | Owner |
|---|---|---|---|---|---|
| AG1 | `architect.md` | **Ambiguity: security rules authorship.** Description says "approve schema and security rule changes." The `write-security-rule` skill is listed as Architect-owned. The handoff contract says "Architect to Functions Dev: migration + rules." In practice during Sprint 1, Architect wrote the rules directly. The description should say "writes" not just "approves". | **High** | **Fix now** — clarify that Architect drafts Firestore/Storage Security Rules and Functions Dev reviews and refines the corresponding tests. Cheap edit, high clarity for Sprint 2. | Architect |
| AG2 | `qa.md` | **Missing responsibility: integration test seeding.** QA owns test specs and reviews, but the responsibility for ensuring integration tests are reproducible from a clean emulator state (no external data dependencies) is not explicit. This emerged as critical during PRs #10-#12 (rules test race condition). | Medium | **Fix now** — add to QA outputs: "Integration test design that includes emulator seeding strategy and teardown guarantees." | QA |
| AG3 | `devops.md` | **Missing: Jest config separation.** Three Jest configs exist (`jest.config.js`, `jest.rules.config.js`, `jest.integration.config.js`), but DevOps description does not mention managing this separation or ensuring CI uses the correct config per test type. | Medium | **Fix now** — add to DevOps responsibilities. Cheap edit. | DevOps |
| AG4 | `flutter-dev.md`, `functions-dev.md` | **Accurate.** Descriptions match Sprint 1 scope of work. No gaps identified. | — | None | — |

---

## 3.3 Skill Catalogue

| # | Skill | Finding | Severity | Action | Owner |
|---|---|---|---|---|---|
| SK1 | All 14 skills | **No dead weight.** All skills were either exercised or have clear future use cases. `write-release-notes` and `update-srs` are correctly dormant (release-time and post-sprint use). | — | Accept | — |
| SK2 | `scaffold-cloud-function` | **Five-layer test pattern not in skill procedure.** The skill creates a basic test file but does not guide developers through the full five-layer test pyramid established in PR #12 (algorithm unit, property, boundary, rules, integration). | Medium | **Fix now** — expand the skill procedure to include the five-layer structure. Sprint 2 will create new Cloud Functions (expense triggers, settlement triggers); the skill should guide them correctly. | Architect |
| SK3 | `write-security-rule` | **Field-level rules pattern demonstrated but not explained.** The positive example shows `affectedKeys()` but does not explain when or why to use it. | Low | Backlog — add explanatory section. The pattern is well-demonstrated in `firestore.rules` and will be documented via proposed ADR-0010. | Architect |

---

## 3.4 Shared Invariants

### Enforcement Depth by Invariant

| Invariant | Hook | Security Rules | Tests | Code / Types | Layers | Verdict |
|---|---|---|---|---|---|---|
| **1. Integer paise** | None | N/A (type enforcement) | Good (algorithm tests verify paise) | Strong (`int`/`number` types) | 2 | Adequate |
| **2. simplifiedBalances server-only** | Working | Strong (`affectedKeys()`) | Excellent (13 rules tests) | Strong (CF transaction) | **4** | **Excellent** |
| **3. System share sheet only** | Working (fragile) | N/A (client-driven) | Missing | Compliant (no violations) | 2 | Weak |
| **4. Single Firebase project** | **Fragile** | N/A | Missing | Accidentally compliant | **1** | **Critical** |

| # | Finding | Severity | Action | Owner |
|---|---|---|---|---|
| INV1 | **Invariant 4 enforcement is critically thin.** The only enforcement layer (hook) has a JSON extraction fragility. There is no automated CI test that verifies only one project ID exists in `.firebaserc`/`firebase.json`. A second project could be added without detection. | **High** | **Fix now** — (1) fix the hook per H1, (2) add a CI check that asserts `.firebaserc` contains exactly one project ID. | DevOps |
| INV2 | **Invariant 3 has no test coverage.** The hook blocks platform-specific imports, but there is no integration or unit test verifying that all share actions use the system share sheet. Sprint 2 introduces friend invites — the first real sharing use case. | Medium | Backlog — add share-sheet verification tests when sharing features are implemented in Sprint 2. | QA |
| INV3 | **No float/double rejection hook for Invariant 1.** The type system provides strong enforcement, but there is no PreToolUse hook that would flag a `double amountRupees` declaration during development. | Low | Backlog — consider adding a hook, but type-system enforcement is sufficient for now. Dart's `int` and TypeScript's `number` (used consistently as integer in tests) provide adequate protection. | Architect |
| INV4 | **Consider promoting field-level diff rules pattern.** The `affectedKeys()` pattern from PR #12 is load-bearing for Invariant 2 and will be reused for all future collections. It could be formalised in `invariants.md` or via the proposed ADR-0010. | Low | Accept — ADR-0010 (proposed in Phase 1, finding A2) will document this. Promoting to a fifth invariant is premature until more collections use it. | Architect |

---

## 3.5 Conventions-Doc Accuracy

| # | Finding | Severity | Action | Owner |
|---|---|---|---|---|
| CN1 | **Cloud Functions five-layer test pattern not in conventions doc.** Section 3 covers Flutter test discipline but is silent on Cloud Functions. Sprint 2 will introduce new CFs; developers need guidance. | **High** | **Fix now** — add section 3.4 "Cloud Functions Testing Layers" to `feature-pr-conventions.md`. | Architect |
| CN2 | **Field-level rules pattern not in conventions doc.** The `affectedKeys()` pattern is not documented. Sprint 2 friendship rules will need this pattern. | Medium | **Fix now** — add to conventions doc. Cross-references proposed ADR-0010. | Architect |
| CN3 | **Jest config separation not documented.** `jest.config.js` vs `jest.rules.config.js` vs `jest.integration.config.js` distinction is not in the conventions doc. | Medium | Backlog — add note to the CF testing section (CN1). | DevOps |
| CN4 | **Cloud Functions PR checklist items missing.** Section 6 does not call out CF-specific checks (region pinning, error code mapping, transaction usage, idempotency). | Low | Backlog — expand during Sprint 2. | Architect |

---

## Summary

| Category | High | Medium | Low | Total |
|---|---|---|---|---|
| Hooks (3.1) | 1 | 0 | 2 | 3 |
| Agent descriptions (3.2) | 1 | 2 | 0 | 3 |
| Skill catalogue (3.3) | 0 | 1 | 1 | 2 |
| Invariants (3.4) | 1 | 1 | 2 | 4 |
| Conventions (3.5) | 1 | 2 | 1 | 4 |
| **Total** | **4** | **6** | **6** | **16** |

### Preliminary Triage

**Fix now candidates (9):** H1 (hook JSON extraction), AG1 (architect rules clarity),
AG2 (QA seeding), AG3 (DevOps Jest config), SK2 (scaffold-CF skill), INV1
(invariant 4 enforcement), CN1 (CF test layers in conventions), CN2 (field-level
rules in conventions).

**Backlog candidates (5):** INV2, INV3, SK3, CN3, CN4.

**Accept candidates (2):** SK1, INV4.
