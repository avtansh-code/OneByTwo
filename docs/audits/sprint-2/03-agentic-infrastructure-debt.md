# Phase 3 — Agentic Infrastructure Debt Review

**Date:** 2026-06-24
**Lead:** Architect
**Consulting:** DevOps

Method: read the three PreToolUse hooks + `hooks.json`; the eight agent charters and
`.github/agents/README.md`; the skill catalogue and the deepened
`review-pull-request/SKILL.md` (14 dimensions); `invariants.md`,
`milestone-tracking.md`, and `feature-pr-conventions.md`; and the Sprint-2
invariant guards (`share_boundary_contract_test.dart` #76, the 20
`*_boundary_contract_test.dart` files, `no-double-on-money-fields.test.ts`,
`firestore.rules`). Hook *firing* is assessed structurally and by outcome (did any
invariant violation ship?), since per-session hook logs are ephemeral. The 3.3
analysis is cross-referenced against the Phase-1 HIGH findings (S6, T1, T2).

---

## 3.1 Hook Firing Audit

The three PreToolUse hooks (`Edit|Write` matcher) are registered in `hooks.json` and
structurally sound (jq with a regex fallback — the Sprint-1 H1 fix held). **Outcome:
no invariant violation shipped in Sprint 2** — Phase-1 confirmed money is paise-only,
`simplifiedBalances` is never client-written (T13), and sharing uses `share_plus`.
Invariants are now defended in **two layers** (real-time hook + CI boundary-contract
test), which is the right posture.

| ID | Location (file:line) | Finding | Severity | Action | Owner |
|---|---|---|---|---|---|
| H1 | `.github/hooks/hooks.json`; the three `pre-tool-use/*.sh` | **Hooks held through Sprint 2's first heavy exercise of the share-sheet and `simplifiedBalances` boundaries.** No false positive blocked legitimate work (the simplifiedBalances hook scopes to `lib/*`, so the Cloud-Function writer in `functions/src/` is correctly exempt), and no violation reached `main`. | — | None (PASS) | — |
| H2 | `block-simplified-balances-write.sh:27-33` | **Relative-path scope is a latent false-negative.** The guard only proceeds when `FILE_PATH` matches `lib/*`; an absolute path (`/…/lib/features/…`) or a `lib`-relative path with a different prefix slips to `exit 0` without checking. The shipped outcome was safe (defended by `firestore.rules` + the review skill), but the hook's own coverage is path-format-dependent. | Low | Backlog — match `*lib/*` (or normalise the path) so the check is path-format-independent. | DevOps |
| H3 | `block-platform-share-targets.sh:46` vs `test/features/friends/share_boundary_contract_test.dart` | **Hook blocklist is package-name-only; it misses raw deep-links.** The pattern matches `whatsapp_share`/`telegram_share`/… but not URI schemes (`whatsapp://`, `https://wa.me/…`) or `launchUrl` deep-links to a messaging app. The #76 boundary-contract test *does* grep imports **and** deep-links under `lib/`, so the gap is caught at CI — but not in real time by the hook. | Low | Backlog — add URI-scheme patterns to the hook blocklist to mirror the #76 contract. | DevOps |
| H4 | issue #27 (Sprint 4 milestone); `functions/test/boundary-contracts/no-double-on-money-fields.test.ts` + 20 `*_boundary_contract_test.dart` | **The float/double rejection hook (#27) is still deferred — and the deferral is sound.** Invariant 1 is meanwhile enforced by `no-double-on-money-fields.test.ts` and the per-feature boundary-contract grep tests, plus the type system. The real-time hook would add belt-and-braces but is not load-bearing given the test layer. | — | Accept (confirm #27 stays Sprint 4) | DevOps |

---

## 3.2 Agent Description Accuracy

Sprint-2 work routed to the right agents (feature PRs → flutter-dev/functions-dev;
rules → architect drafts + functions-dev tests; close-out → pm/qa/devops). The #77
milestone duties landed correctly: `milestone-tracking.md` is referenced by
`orchestrator.md` (6), `qa.md` (5), `devops.md` (5), `pm.md` (3) and the agents
README; the implementer charters (architect/flutter-dev/functions-dev/designer) are
milestone-silent, which is correct — milestone reconciliation is the **merger's** duty,
carried in the review skill (SKILL.md:185-192, 231).

| ID | Location | Finding | Severity | Action | Owner |
|---|---|---|---|---|---|
| AG1 | `pm.md`, `qa.md`, `devops.md`, `orchestrator.md`; `milestone-tracking.md:92-101` | **#77 milestone responsibilities are accurately charted.** PM owns "milestone exists / assign at creation"; QA owns "reconcile on merge"; DevOps owns "close at sprint end / source release scope". Matches the ownership table and how the close-out PRs (#74-#77) actually behaved. | — | None (PASS) | — |
| AG2 | (no charter) vs Phase-1 **S6**, Phase-2 **PY3** | **An emergent responsibility is unowned: end-to-end reachability / orphaned-code detection.** S6 (the add-friend flow is unreachable — an orphaned screen + a never-overridden provider) shipped because no charter or skill requires verifying that a shipped feature is reachable from a navigation entry point and exercised by an *executable* test (only a skipped stub existed). QA owns test *plans* but not "wiring reachability". | Medium | Fix now — add a "critical-journey reachability (no orphaned screens/providers; an executable end-to-end test exists)" duty to `qa.md`, paired with the SK2 review-skill check. | Architect (text) + QA |

---

## 3.3 Skill Catalogue

Sixteen skills; all exercised or clearly relevant in Sprint 2 (scaffold-flutter-feature,
scaffold-cloud-function, write-widget-test, write-security-rule,
simplified-debts-test-case, new-user-story, refine-acceptance-criteria, triage-bug,
setup-emulator-suite, write-integration-test, review-pull-request, …). No dead weight.

| ID | Location | Finding | Severity | Action | Owner |
|---|---|---|---|---|---|
| SK1 | `.github/skills/*` | **Catalogue is healthy — no dead skill.** Each skill maps to a real Sprint-2 activity. | — | None (PASS) | — |
| SK2 | `review-pull-request/SKILL.md:115-120, 172-183` vs Phase-1 **T1, T2, S6** | **The deepened 14-dimension review skill has exactly three blind spots — and they are the three Phase-1 HIGH findings.** (a) *Telemetry* checks UID-composite hashing but never the `amount_range` bucketing rule (`telemetry-plan.md` §2.1) → would **miss T1** (raw `amount_paise`). (b) *Privacy* says "hash UID-composites via `hashFriendshipId`" but does not flag that a full hash of a phone number is still reversible PII → would **likely miss T2** (`phone_hash`), with only the general "No PII" line as partial cover. (c) No *reachability / orphaned-code / "critical journey exercised by an executable test"* check → would **miss S6** unless the acceptance-criteria dimension were applied against an executable test (which did not exist). | Medium | Fix now — add three checks: "amounts bucketed to `amount_range`, never raw `amount_paise`" (Telemetry); "phone numbers never appear in telemetry, even hashed" (Privacy); "no orphaned screen/provider — a new critical journey is reachable and covered by an executable end-to-end test" (Tests/Acceptance). | Architect |
| SK3 | `test/features/**/*_boundary_contract_test.dart` (20 files); no skill | **A repeated capability has no named skill: the boundary-contract grep test.** Twenty per-feature boundary-contract tests follow one pattern, but there is no `write-boundary-contract-test` skill (it lives only as prose in `feature-pr-conventions.md` §3). | Low | Backlog — promote to a named skill or extend `write-widget-test` to cover the boundary-contract pattern. | QA |

---

## 3.4 Shared Invariants

All four invariants were exercised by Sprint-2 guards and held; #72 (creator-only
expense edit/soft-delete) is enforced in `firestore.rules` with negative rules tests,
not only in the UI.

| ID | Location | Finding | Severity | Action | Owner |
|---|---|---|---|---|---|
| INV1 | `share_boundary_contract_test.dart` (#76), `no-double-on-money-fields.test.ts`, the 20 `*_boundary_contract_test.dart`, `firestore.rules` (creator-only #72; `simplifiedBalances`/`verificationStatus` read-only) | **The four invariants survived their first heavy test.** INV1 (paise) — boundary contracts green; INV2 (`simplifiedBalances`) — hook + rules + Phase-1 T13; INV3 (share sheet) — #76 contract (imports + deep-links) + hook; INV4 (single project) — hook + the Sprint-1 `.firebaserc` CI guard. No violation shipped. | — | None (PASS) | — |
| INV2c | `firestore.rules` (`verificationStatus` client-read-only mirroring `simplifiedBalances`); `extension-points-register.md` ARCH-EXT-06; Sprint-1 audit INV4 | **New load-bearing invariant candidate: "server-maintained projections are client-read-only."** Sprint 2 added `verificationStatus` as a *second* server-written / client-read-only field enforced by the same `affectedKeys()` diff pattern as `simplifiedBalances`. Invariant 2 is now arguably an instance of a broader class. Sprint-1 (INV4) deferred promoting the field-level-diff pattern; with two instances, the case is stronger. (Relates to Phase-1 A4/A5.) | Medium | Accept + document — capture the generalisation in an ADR (or fold into ADR-0010) rather than reword Invariant 2 yet; revisit after Sprint-3 groups add `groups.simplifiedBalances`. | Architect |

---

## 3.5 Conventions-Doc Accuracy

`feature-pr-conventions.md` is comprehensive and the #75/#77 additions are present
(Phase-1 P4 confirmed). Two Sprint-2 patterns are documented in the review skill but
not yet in the conventions doc — a doc-vs-doc gap.

| ID | Location | Finding | Severity | Action | Owner |
|---|---|---|---|---|---|
| CN1 | `feature-pr-conventions.md:51-72` (§2) vs `review-pull-request/SKILL.md:94-96` and Phase-1 **M5** | **The scoped-provider `dependencies:` rule is missing from §2.** §2 covers provider location/naming/types but not the FR-HD/FR-FR rule ("a provider that watches a *scoped* provider declares the directly-watched scoped provider, not the transitive root"). The rule is in the review skill but absent from both this doc *and* `state-management.md` (M5) — three-way inconsistency. | Medium | Fix now — add the scoped-`dependencies` rule to §2 (and fix `state-management.md` per M5) so all three docs agree. | Architect |
| CN2 | `feature-pr-conventions.md` (no mention) vs `review-pull-request/SKILL.md:79-82`, `extension-points-register.md` | Extension-point obligations (`method`/`currency`/`verificationStatus` with `verificationStatus` client-read-only) are in the review skill and the register but not referenced in the conventions doc's CF checklist (§6) or test discipline (§3). | Low | Backlog — add a one-line pointer in §6 to the extension-point obligations (register is the authoritative home). | Architect |

---

## Summary

| Sub-part | High | Medium | Low | PASS/None |
|---|---|---|---|---|
| 3.1 Hook firing | 0 | 0 | 3 (H2, H3, H4) | H1 |
| 3.2 Agent accuracy | 0 | 1 (AG2) | 0 | AG1 |
| 3.3 Skill catalogue | 0 | 1 (SK2) | 1 (SK3) | SK1 |
| 3.4 Invariants | 0 | 1 (INV2c) | 0 | INV1 |
| 3.5 Conventions | 0 | 1 (CN1) | 1 (CN2) | — |
| **Total** | **0** | **4** | **5** | 4 PASS |

### Preliminary Triage (Phase 6 finalises)

- **Fix now:** SK2 (close the three review-skill blind spots that map to S6/T1/T2 —
  highest-leverage fix in this phase), AG2 (add the reachability duty to QA),
  CN1 (scoped-`dependencies` rule into conventions §2, with M5).
- **Backlog:** H2, H3 (hook coverage hardening), SK3 (boundary-contract skill),
  CN2 (extension-point pointer in conventions).
- **Accept + document:** H4 (float hook stays Sprint 4), INV2c (server-projection
  generalisation → ADR).

> Headline: the agentic infrastructure is **fundamentally sound** — the hooks and the
> two-layer invariant guards held through Sprint 2 with no violation shipped, milestone
> duties are correctly charted, and the skill catalogue has no dead weight. The single
> highest-value finding is **SK2**: the deepened `review-pull-request` skill — the very
> instrument meant to catch quality regressions — has three precise blind spots that
> line up one-to-one with the Phase-1 HIGH findings (T1 amount bucketing, T2 phone-hash
> PII, S6 reachability). Closing those three gaps hardens the review lens for Sprint 3.
