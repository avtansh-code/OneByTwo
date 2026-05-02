# Phase 6 — Triage and Decision

**Date:** 2026-05-02
**Owner:** Orchestrator

---

## Consolidation

Phases 1 through 5 produced **74 findings** across five audit reports:

| Phase | Title | High | Medium | Low | Total |
|---|---|---|---|---|---|
| 1 | Documentation drift | 7 | 10 | 6 | 23 |
| 2 | Test-suite health | 0 | 2 | 6 | 8 |
| 3 | Agentic infrastructure debt | 4 | 6 | 6 | 16 |
| 4 | Dependency and security | 0 | 8 | 7 | 15 |
| 5 | Sprint 2 pre-flight readiness | 5 | 4 | 3 | 12 |
| **Total** | | **16** | **30** | **28** | **74** |

---

## Bucket A — Fix Now (PR #14)

Bar: would this materially affect Sprint 2 quality if left unfixed?

### Code Fixes (require testing)

| ID | Phase | Finding | Rationale |
|---|---|---|---|
| **F1** | 1.2 | **`paidBy` → `payerId` in `function.ts:134`.** Field name mismatch between Cloud Function and schema. Sprint 2 exercises simplified-debts (confirmed in Phase 5); this would cause runtime failure when expenses are created. | Sprint 2 blocker. Critical path. |
| **T2** | 1.5 | **Add `signup_completed` event.** Core funnel event missing from code. Without it, the signup funnel cannot be measured. | SRS section 5.10 requirement. Affects analytics quality. |
| **T1** | 1.5 | **Rename `signup_otp_screen_viewed` → `otp_screen_viewed`.** Event name does not match telemetry plan. | Prevents funnel analysis confusion in Sprint 2. |
| **H1** | 3.1 | **Fix hook JSON extraction.** Replace regex-based extraction with `jq` in all three PreToolUse hooks. Invariant 4 enforcement depends on this. | Only enforcement layer for Invariant 4. |
| **SR4** | 5.3 | **Add contact picker permissions.** `NSContactsUsageDescription` in iOS Info.plist, `READ_CONTACTS` in Android AndroidManifest.xml. | Sprint 2 blocker. Runtime failure without them. |

### Documentation Fixes (low risk, high value)

| ID | Phase | Finding | Rationale |
|---|---|---|---|
| **A1** | 1.6 | **Write ADR-0009:** Sealed-union auth state pattern. | Template for Sprint 2 state machines. Load-bearing. |
| **A2** | 1.6 | **Write ADR-0010:** Field-level Firestore rules (`affectedKeys()`). | Sprint 2 friendship rules will copy this pattern. |
| **A3** | 1.6 | **Write ADR-0011:** Cloud Function module layout (pure + boundary). | Sprint 2 CFs will copy this pattern. |
| **C1** | 1.3 | **Update CF catalogue:** trigger type (callable, not internal module). | Prevents Sprint 2 agents from assuming trigger functions exist. |
| **C2** | 1.3 | **Update CF catalogue:** add Status column (shipped vs planned). | Same rationale as C1. |
| **M2** | 1.4 | **Update state-management doc:** use `*ControllerProvider` names matching code. | Prevents Sprint 2 developers from using wrong provider names. |
| **T6** | 1.5 | **Update telemetry plan per ADR-0007:** `signup_started` trigger description. | Stale doc creates ambiguity. |
| **S2** | 1.1 | **Add deferral note to SCR-02 (onboarding).** | Prevents re-discovery as a "bug". |
| **AG1** | 3.2 | **Clarify architect.md:** Architect drafts rules, Functions Dev tests. | Prevents routing confusion in Sprint 2. |
| **AG2** | 3.2 | **Update qa.md:** add integration test seeding responsibility. | Emerged as critical during Sprint 1 rules test race. |
| **AG3** | 3.2 | **Update devops.md:** add Jest config separation responsibility. | Prevents config misuse in Sprint 2 CI. |
| **SK2** | 3.3 | **Update scaffold-CF skill:** add five-layer test structure. | Sprint 2 creates new CFs; skill must guide correctly. |
| **CN1** | 3.5 | **Add CF testing layers to conventions doc.** | Sprint 2 developers need testing guidance. |
| **CN2** | 3.5 | **Add field-level rules pattern to conventions doc.** | Sprint 2 friendship rules need this reference. |
| **INV1** | 3.4 | **Add CI check for single Firebase project** in `.firebaserc`. | Invariant 4 has no reliable enforcement. Cheap CI addition. |
| **SR1** | 5.1 | **Write user stories** for FR-FR-01, FR-FR-02, FR-FR-03. | Sprint 2 DoR blocker. Stories must exist before PRs open. |
| **SR2** | 5.1 | **Finalise screen spec** `09-12-friends.md` (currently draft). | Sprint 2 development needs final spec. |
| **SR6** | 5.4 | **Add `friend_search_started` event** to telemetry plan. | Friend discovery funnel unmeasurable without it. |
| **SR7** | 5.4 | **Add `contact_permission_granted` event** to telemetry plan. | Asymmetric observability (only denial tracked). |
| **SR9** | 5.5 | **Add R-17 (contact permission fragility)** to risk register. | Notorious friction source, completely absent from risks. |
| **SR10** | 5.5 | **Add permission denial UX** to friends screen spec. | No fallback UI documented for denied contact access. |
| **SR11** | 5.5 | **Add privacy note:** contacts processed client-side only. | Implicit but not documented. Sprint 2 agents need clarity. |

**Bucket A total: 27 findings (5 code, 22 documentation).**

---

## Bucket B — Backlog for Sprint 2 Chore

Bar: creates friction in Sprint 2 but can wait for a natural moment.

| ID | Phase | Finding | Notes |
|---|---|---|---|
| M1 | 1.4 | Rename `authStateNotifierProvider` → `authStateProvider`. | Misleading name (StreamProvider with "Notifier" suffix). Touches 10+ files. Better as a dedicated chore PR to manage test impact. |
| T3 | 1.5 | Clarify `signup_otp_submitted` event (not in plan). | Low impact; fold into next OTP screen touch. |
| T4 | 1.5 | Add missing secondary telemetry events (`otp_send_requested`, `phone_entry_viewed`, etc.). | Secondary funnel events. Add during next auth touch. |
| T5 | 1.5 | Fix `is_new_user` parameter type (int→bool). | Minimal functional impact. |
| M4 | 1.4 | Relocate core providers to `lib/core/providers/`. | Sprint 2 will add more features needing these providers. Natural moment to move. |
| S1 | 1.1 | Splash screen timeout/error state alignment. | Functional as-is. PM to decide. |
| S3 | 1.1 | Phone entry OTP error: inline vs snackbar. | Functional as-is. PM to decide. |
| S4 | 1.1 | Phone entry live formatting (XXXXX XXXXX). | Polish item. |
| S5 | 1.1 | OTP resend exhausted message text alignment. | Cosmetic. |
| P1 | 1.7 | Add CF testing layers to conventions doc (overlaps CN1). | Covered by CN1 in Bucket A. |
| P2 | 1.7 | Add CF module layout to conventions doc. | Covered by ADR-0011 in Bucket A. |
| F2 | 1.2 | Group create rules missing `adminId` validation. | Groups are Sprint 3. Fix when groups ship. |
| CV2 | 2.1 | Add coverage section to PR description template. | Process improvement. |
| CV3 | 2.1 | Functions `function.ts` branch coverage at 76%. | Improve when expense triggers are wired. |
| RT2 | 2.3 | Add CI step duration logging. | Monitoring improvement. |
| PY3 | 2.4 | Expand integration tests for Sprint 2 flows. | Natural Sprint 2 work. |
| SC1 | 2.5 | Concurrent submit guard test for phone entry. | Add during next touch. |
| SC2 | 2.5 | Auto-retrieval timeout path test. | Add during Android auto-read refinement. |
| SC3 | 2.5 | `MAX_SAFE_INTEGER` overflow test for algorithm. | Add to canonical test suite. |
| SC4 | 2.5 | Large group (100+) scalability test. | Add when groups ship (Sprint 3). |
| SK3 | 3.3 | Explain field-level rules pattern in skill. | Covered by ADR-0010 and CN2 in Bucket A. |
| INV2 | 3.4 | Share-sheet test coverage. | Add when sharing features are implemented. |
| INV3 | 3.4 | Float/double rejection hook. | Type system is sufficient. Low priority. |
| CN3 | 3.5 | Jest config separation in conventions doc. | Fold into CN1. |
| CN4 | 3.5 | CF-specific PR checklist items. | Add during Sprint 2. |
| D1 | 4.1 | Riverpod 3.x migration. | Major effort. Dedicated chore PR. |
| D2 | 4.1 | `share_plus` upgrade (10→13). | Evaluate before first share-using PR. |
| D4 | 4.1 | `build_runner` upgrade (discontinued transitives). | Low urgency. |
| D5 | 4.2 | `firebase-functions` 7.x evaluation. | Evaluate before Sprint 2 CF work. |
| D6 | 4.2 | npm audit moderate vulnerabilities. | Resolve when firebase-admin/functions upgraded. |
| D7 | 4.2 | Jest/TypeScript/ESLint major bumps. | Non-urgent. |
| R1-R6 | 4.3 | Firestore rules test gaps (friendships/groups validation). | Add when features ship. |
| R7-R8 | 4.4 | Storage rules test gaps (file size, content-type). | Non-blocking. |
| S2 | 4.5 | Release pipeline secrets configuration. | Before Sprint 6. |
| SR3 | 5.2 | Friends HTML mockup missing. | Screen spec compensates. |
| SR8 | 5.4 | Expense event naming asymmetry. | Decide before expense stories. |
| SR12 | 5.5 | DPDP legal sign-off scheduling. | Before Sprint 6. |

**Bucket B total: 37 findings.**

---

## Bucket C — Accept and Document

Bar: deliberate trade-off or acceptable imperfection. Document so it is not
re-discovered.

| ID | Phase | Finding | Acceptance Rationale |
|---|---|---|---|
| F3 | 1.2 | Dart models for expenses/settlements/friendships/groups don't exist. | Expected. These are Sprint 2+ features. Models are created when their collections are implemented. |
| M3 | 1.4 | ~85 documented providers not yet implemented. | Expected. Provider tree describes the full v1.0 target; Sprint 1 implemented auth/profile only. |
| P3 | 1.7 | Feature folder layout and commit messages are compliant. | No action needed. |
| FL2 | 2.2 | `maxWorkers: 1` constraint for rules tests. | Already fixed and documented in retro. |
| PY2 | 2.4 | Functions test pyramid is security-heavy. | Intentional. Justified by Invariant 2 enforcement needs. |
| SK1 | 3.3 | All 14 skills are justified (no dead weight). | Healthy catalogue. |
| INV4 | 3.4 | Field-level diff pattern not promoted to invariant. | Premature. ADR-0010 captures it. May revisit after Sprint 3 (groups). |
| D3 | 4.1 | Firebase SDK packages are current. | Healthy. No action. |
| S1_sec | 4.5 | No new secrets needed for Sprint 2. | Confirmed. |

**Bucket C total: 9 findings.**

---

## Totals

| Bucket | Count | % |
|---|---|---|
| A — Fix now (PR #14) | 27 | 37% |
| B — Backlog | 37 | 50% |
| C — Accept | 9 | 12% |
| Informational (no finding) | 1 | 1% |
| **Total** | **74** | **100%** |

Every finding has been explicitly triaged. None fall into the gap between buckets.

---

## Decision: PR #14 Required

**Bucket A is non-empty (27 findings).** Per Phase 0 framing, this session produces
**PR #14: `chore: Sprint 1 boundary cleanup and audit findings`**.

The PR will contain:
- **5 code fixes** (paidBy rename, signup_completed event, otp event rename, hook
  JSON extraction, contact permissions)
- **22 documentation updates** (3 ADRs, CF catalogue, state-management doc, telemetry
  plan, agent descriptions, skill update, conventions doc, user stories, screen spec,
  risk register, privacy note)

Phase 7 will execute this decision.
