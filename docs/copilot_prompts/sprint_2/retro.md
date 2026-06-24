You are the OneByTwo orchestrator agent. Sprint 2 (Friends and Core Expenses) is complete. The three consolidated close-out PRs have merged — #74 (`chore(auth)`, `ce6d594`), #75 (`docs`, `dbc209d`), and #76 (`test`, `3f3cd16`) — closing the Sprint-2 chore backlog (#15–#20, #24, #28; #21/#25/#47 closed earlier in the sprint). The single committed remainder is the **#23 Flutter emulator integration-harness** (RT2 + INV2 shipped with evidence in #76; the PY3 Flutter-harness remainder is deferred). Since then, **PR #77 (`b9b1e63`, squash) has merged** — a tooling/governance bundle that (a) added **path-based change detection** to `.github/workflows/pr.yml`, (b) introduced the **milestone-tracking convention** (`.github/shared/milestone-tracking.md`, wired into the agents and the issue/PR-lifecycle skills), and (c) **deepened the `review-pull-request` skill** to 14 design-grounded review dimensions. GitHub **Milestones now exist** (Sprint 2 closed at 100% with its 13 issues linked; Sprint 3 / 4 / 5 / 6 / Post-v1.0 open) and the legacy `sprint-2-chore` label is historical (closed issues only).

Velocity through #76 is **142 SP / 34 counted PRs**; #77 was **velocity-excluded** (CI + governance, like #59 / #61 / #73 / #75), so the Total is unchanged. With every P0 except the Sprint-3 Groups epic and every P1 shipped, this session is the **Sprint 2 → Sprint 3 boundary sweep**: a retrospective and audit, mirroring the Sprint-1 `retro.md` precedent, run **before** the Sprint 3 Groups epic (FR-GR-01..07, FR-SE-05..08, FR-EX-06/07 in group context) opens.

This session has two possible outcomes:
  - A "Sprint 2 boundary cleanup" PR (the next available number, ≥ #78) with the fixes the audit identifies.
  - A standalone audit report set under `docs/audits/sprint-2/` if no fixes are needed.

The orchestrator decides which, based on what the audit finds. Do not pre-commit to one. Run the audit first; let the findings dictate the response.

Read before starting:
  - `.github/copilot-instructions.md`
  - `.github/shared/invariants.md`
  - `.github/shared/decision-log.md` (all ADRs; Sprint 2 added through ADR-0020)
  - `.github/shared/coding-standards.md`, `.github/shared/handoffs.md`
  - `.github/shared/milestone-tracking.md` (NEW in #77 — the milestone lifecycle; this changes how Bucket-B findings are filed: a milestone, not the deprecated `sprint-2-chore` label)
  - `.github/skills/review-pull-request/SKILL.md` (NEW depth in #77 — use its 14 review dimensions as the audit lens)
  - `docs/patterns/feature-pr-conventions.md`
  - `docs/copilot_prompts/sprint_1/retro.md` (the precedent this session mirrors)
  - `docs/audits/sprint-1/` (the report structure to mirror under `docs/audits/sprint-2/`)
  - `docs/sprint-zero/sprint-2-plan.md` (final state, PR Tracking + Velocity, the close-out section)
  - `docs/sprint-zero/next-three-prs.md` (rolling roadmap)
  - `docs/design/08-plan/sprint-sequence.md` (Sprint 3 scope)
  - `docs/design/08-plan/dependencies-and-critical-path.md`

Standing caveats (read first):
  - **PR numbering.** Issues and PRs share one sequential namespace; any cleanup PR lands as the next available number (≥ #78 now that the highest PR is #77 and the highest issue is #68). Reconcile the slot label at PR open.
  - **CI title-lint.** `.github/workflows/pr.yml` enforces a single-token conventional-commit scope and a subject ≤ 72 ASCII chars. Keep the title ASCII (no em-dash).
  - **Change detection.** Since #77, a pure-docs audit PR (touching only `docs/**`) runs **only the PR Title Lint** — the Flutter/Functions/build/integration/coverage jobs skip (and pass the ruleset as "skipped"). A cleanup PR that touches `lib/**`, `functions/**`, the rules, or a workflow file re-engages the corresponding jobs.
  - **fvm.** Commit with `fvm exec git commit` and push with `fvm exec git push` where lefthook is installed; run pub/build commands via the fvm-pinned SDK (bare `flutter` may use an older system SDK and downgrade `pubspec.lock`).

────────────────────────────────────────
PHASE 0 — SCOPE AND OUTPUT FRAMING
────────────────────────────────────────

The orchestrator commits to the framing of this session in writing:

  - This is an AUDIT, not feature work. No new features ship in this session, and the Sprint 3 Groups epic is NOT started here.
  - Findings are categorised into three buckets: (a) fix now in the cleanup PR, (b) backlog as a tracked issue assigned to the appropriate sprint **milestone** (per `.github/shared/milestone-tracking.md` — NOT the deprecated `sprint-2-chore` label), (c) accept and document.
  - The bar for "fix now": would this materially affect Sprint 3 quality if left unfixed? If yes, fix now. If no, backlog or accept.
  - The bar for "backlog": would Sprint 3 work create friction with this issue, or is it a follow-up that can wait? File it as an issue on the milestone that owns the work (default Sprint 3; Post-v1.0 for explicitly post-launch items).
  - The bar for "accept and document": a deliberate trade-off recorded in an ADR or the retro so it is not re-discovered later as a "bug".

Each finding gets explicitly triaged. None should fall into the gap between buckets.

────────────────────────────────────────
PHASE 1 — DOCUMENTATION DRIFT AUDIT
────────────────────────────────────────

Owner: architect (lead) + pm (consulting).

Compare the design docs against what actually shipped across the Sprint-2 PRs (#15–#76). Specifically:

1.1  `docs/design/06-screen-specs/` — for every screen that shipped this sprint (friends list, add friend, contact picker, friend detail; add/edit expense, receipt attachment; settlement history; activity feed; home dashboard + FAB + spend-breakdown chart; notification preferences; change-phone; delete-account; the bottom-nav shell), check the spec still describes what was built. Drift can run in either direction (implementation diverged, or spec described something cut/deferred).

1.2  `docs/design/07-technical/firestore-schema.md` — Sprint 2 introduced/populated `friendships`, `expenses`, `settlements`, and `activity` documents. Every field the implementation writes should appear in the schema doc, and vice versa. Pay attention to the server-managed projections (`simplifiedBalances`) and the settlement extension-point fields (`method`, `currency`, `verificationStatus`).

1.3  `docs/design/07-technical/cloud-functions-catalogue.md` — does it accurately describe every function as shipped: `recomputeSimplifiedBalances`, `onExpenseWriteFriendship`, `onSettlementWrite`, `lookupUserByPhoneNumber`, `sendReminderNotification`, `deleteUserAccount`? Are the function-boundary error codes (`HttpsError` mappings) catalogued?

1.4  `docs/design/07-technical/state-management.md` — does the real Riverpod provider tree match? Are providers named per convention and located in each feature's `application/` folder? Are scoped providers' `dependencies` lists correct (the FR-HD/FR-FR scoping trap)?

1.5  `docs/design/07-technical/telemetry-plan.md` — every event that fires in shipped code is in the plan, and every event in the plan fires. Sprint 2 added many events (auth funnel, friends, expenses, settlements, activity, home, permissions). Confirm PII-bearing identifiers are hashed (`hashFriendshipId`).

1.6  Architectural decisions: were any made implicitly during Sprint-2 PRs that should be back-ported as ADRs, or were the Sprint-2 ADRs (through ADR-0020) kept current? Spot-check the charting approach (ADR-0017), the FR-AC-05 deep-link seam (ADR-0018), `app_settings` (ADR-0019), and `shared_preferences`/`KeyValueStore` (ADR-0020) against what shipped.

1.7  `docs/patterns/feature-pr-conventions.md` — has it stayed accurate as Sprint 2 shipped? The #75 additions (coverage fields, CF PR checklist, Jest-config table) and the #77 milestone-tracking convention should be reflected and internally consistent (no doc-vs-doc drift).

Produce `docs/audits/sprint-2/01-documentation-drift.md`. Each finding is a row: location, drift description, severity (high/medium/low), recommended action (fix now / backlog / accept), owner.

────────────────────────────────────────
PHASE 2 — TEST-SUITE HEALTH CHECK
────────────────────────────────────────

Owner: qa (lead) + flutter-dev + functions-dev (consulting).

2.1  Coverage trend across the sprint: pull the before/after coverage lines recorded per PR (the #75 coverage-tracking fields make this auditable). Is coverage trending up, flat, or down for `lib/features/{friends,expenses,settlements,activity,home,profile}/**`, `functions/src/{simplified-debts,triggers,...}/**`, and the rules tests, against the SRS §5.7 thresholds (≥70% non-UI per feature/module, ≥50% overall)?

2.2  Flaky-test detection: any tests that failed and re-passed in CI without code changes? The emulator-dependent suites (rules, integration, canonical) are the likeliest culprits — examine for race conditions, trigger interference, and `clearFirestore()` ordering. Every flaky test is fix-now: (a) fix, (b) mark `// FLAKY: see #N` + file the issue, or (c) delete with rationale. Silent flakiness is unacceptable.

2.3  Test-suite runtime — now under the #77 change-detection pipeline: confirm the RT2 step-duration logging is present and the path-based gating behaves (docs-only PRs skip the heavy jobs; relevant changes re-engage them). Flag any single suite that dominates the PR cycle.

2.4  Test pyramid balance: count unit / widget / integration tests. The base should stay wide. Note the **#23 remainder** — the `test/integration/**/*_flow_test.dart` files are still render-only stubs (no executable `integration_test/` harness; deferred to the Sprint 6 milestone). Confirm that deferral is still the right call and the burndown reflects it.

2.5  Coverage gaps that look like risk: spot-check three modules where the number is high but the failure paths may be thin (error states, empty states, edge boundaries). Sprint 2 wired simplified-debts to live expense/settlement triggers — verify the canonical, property, settlement-folding, reserved-key, and emulator-integration layers still hold.

Produce `docs/audits/sprint-2/02-test-suite-health.md` (same row format).

────────────────────────────────────────
PHASE 3 — AGENTIC INFRASTRUCTURE DEBT REVIEW
────────────────────────────────────────

Owner: architect (lead) + devops (consulting).

3.1  Hook firing audit: across the Sprint-2 PRs, did the PreToolUse hooks (`block-simplified-balances-write.sh`, `block-platform-share-targets.sh`, `block-second-firebase-project.sh`) fire? Any false positives (blocked legitimate work) or false negatives (a violation that slipped past)? Sprint 2 was the first heavy exercise of the share-sheet and `simplifiedBalances`-write boundaries — did the hooks discriminate correctly? Note that INV2 (share-sheet) gained its first automated grep guard in #76 and the float/double hook (#27) remains deferred (Sprint 4 milestone).

3.2  Agent description accuracy: did the orchestrator route Sprint-2 work to the right agents? In particular, the **new milestone duties** added in #77 (PM owns milestone assignment; QA/merging agent reconcile on merge; DevOps closes a sprint milestone at release) — do the agent charters and the `review-pull-request` skill now describe responsibilities that actually held during the close-out? Are there responsibilities that emerged in Sprint 2 that no agent covers?

3.3  Skill catalogue: which skills were invoked during Sprint 2, and which were dead weight? The **deepened `review-pull-request` skill** and the **milestone-tracking convention** (both #77) are new — sanity-check them against real Sprint-2 PRs (would the deeper review have caught anything that shipped?). Are there repeated capabilities that should be promoted to a named skill?

3.4  Shared invariants: were any of the four invariants tested by an attempted violation in Sprint 2 (the creator-only expense rules #72, the share-sheet guard #76, the integer-paise boundary contracts)? What was the result? Any new load-bearing invariant candidate from Sprint-2 design decisions?

3.5  Conventions-doc accuracy: fold any canonical Sprint-2 pattern that is not yet in `feature-pr-conventions.md` into it (avoid doc-vs-doc drift with the #75 / #77 additions).

Produce `docs/audits/sprint-2/03-agentic-infrastructure-debt.md` (same row format).

────────────────────────────────────────
PHASE 4 — DEPENDENCY AND SECURITY AUDIT
────────────────────────────────────────

Owner: devops (lead).

4.1  Flutter dependencies: run `fvm flutter pub outdated` (via the pinned SDK — see the fvm caveat). Triage majors: stay pinned, Sprint 4 milestone (the deferred #22 dependency-upgrade epic — Riverpod 3.x, `share_plus`, `firebase-functions` 7.x), or upgrade now if security/stability. **Verify `pubspec.lock` matches the fvm-pinned SDK** (a bare `flutter pub get` on an older system SDK downgrades transitive deps and the `sdks:` floor — if found, restore the committed lock and record the "use fvm" guidance).

4.2  Cloud Functions dependencies: `cd functions && npm outdated` and `npm audit`. HIGH/CRITICAL advisories are fix-now; MODERATE backlog; LOW accept.

4.3  Firestore rules drift: read `firestore.rules` end-to-end — it grew substantially across Sprint 2 (friendship, expense creator-only #72, settlement, `simplifiedBalances`/`verificationStatus` read-only). Does it read consistently? Any dead/superseded rules? Any rule without a corresponding negative test in `functions/test/firestore-rules/`? Is it nearing a length that warrants splitting (flag for awareness, ~500 lines)?

4.4  Storage rules drift: same review for `storage.rules` — confirm the receipt and avatar size/content-type constraints (R7/R8) have negative tests.

4.5  Secrets and environment: does Sprint 3 (Groups) need any new secrets? Likely none (group cover photos reuse the existing Storage config) — confirm. Note that the release-pipeline secrets + DPDP sign-off (#26) is deferred to the Sprint 6 milestone.

Produce `docs/audits/sprint-2/04-dependency-and-security.md`.

────────────────────────────────────────
PHASE 5 — SPRINT 3 PRE-FLIGHT READINESS
────────────────────────────────────────

Owner: pm (lead) + architect + designer.

Sprint 3 is the Groups and Settlements epic per `docs/design/08-plan/sprint-sequence.md`. Verify it can actually start.

5.1  Scope clarity: read the Sprint 3 stories (FR-GR-01..07, FR-SE-05..08, FR-EX-06/07 in group context). Identify the first three. Are they Definition-of-Ready compliant per `docs/design/08-plan/definition-of-ready-and-done.md`? For FR-GR-01 (Create group) specifically: is there a story file under `docs/sprint-zero/stories/`? Is the screen spec (`docs/design/06-screen-specs/13-18-groups.md`) complete? Are the wireframes (`groups-flow.md`, `settle-up-flow.md`) and mockups (`05-group-detail.html`, `06-settle-up.html`) in place? (All four design artefacts already exist — confirm fidelity, not existence.)

5.2  Design artefacts: the Groups epic introduces new screens and components. Are component-catalogue entries in `docs/design/02-design-system/components.md` present for any new components (group list item, member row, invite-link card, settle-up sheet)?

5.3  Technical readiness: Groups introduce the `groups/{groupId}` collection. Is the schema in `firestore-schema.md` complete (members, roles, invite tokens, `simplifiedBalances`)? Are the group security rules outlined in `firestore-security-rules.md` (admin/member roles, zero-balance guards for remove/leave/delete, the 7-day invite-link expiry, and the **extension-point obligations**: settlements carry `method:'manual'` / `currency:'INR'` / `verificationStatus:'unverified'` with `verificationStatus` client-read-only, mirroring `simplifiedBalances`)? Note `lib/features/groups/` is currently a README/stub — confirm the feature-first scaffold is the first build step. Decide the **`go_router` migration** question (a candidate Sprint-3 enabler in `next-three-prs.md`): is it a prerequisite for the Groups navigation, or deferrable?

5.4  Telemetry: are the Groups events enumerated in `telemetry-plan.md` (at minimum `group_created`, `group_invite_sent`, `group_member_added`, `group_member_removed`, `group_left`, `group_deleted`, `settle_up_opened`, `settlement_recorded`)? PII-bearing group/member identifiers must be hashed.

5.5  Risk register: add Groups-specific risks to `risks-revisited.md` or the Sprint 3 plan — invite-link expiry/revocation security, the zero-balance guards (remove/leave/delete must be enforced server-side, not only in the UI), and the multi-party simplified-debts scalability (the SC4 100+/1000-member algorithm test from #76 de-risks this at the algorithm layer).

Produce `docs/audits/sprint-2/05-sprint-3-readiness.md`.

────────────────────────────────────────
PHASE 6 — TRIAGE AND DECISION
────────────────────────────────────────

Owner: orchestrator.

Consolidate findings from Phases 1–5. Categorise every finding:

  Bucket A — Fix now (the cleanup PR): findings that materially affect Sprint 3 quality; hook false positives/negatives; HIGH/CRITICAL security advisories; anything blocking the first Sprint-3 PR; load-bearing architectural-decision back-ports.

  Bucket B — Backlog: stylistic inconsistencies, optimisations, non-blocking convention updates, future-state docs. **File each as a GitHub issue assigned to the milestone that owns the work** (per `.github/shared/milestone-tracking.md`: default Sprint 3; a later sprint or Post-v1.0 where the source defers it). Do NOT use the deprecated `sprint-2-chore` label.

  Bucket C — Accept and document: deliberate trade-offs recorded in an ADR (`.github/shared/decision-log.md`) or the retro.

Produce `docs/audits/sprint-2/00-triage-summary.md` listing every finding, its bucket, and rationale.

────────────────────────────────────────
PHASE 7 — DECIDE: CLEANUP PR OR STANDALONE REPORT
────────────────────────────────────────

Owner: orchestrator.

If Bucket A is non-empty: open the cleanup PR (next available number, ≥ #78). Title (single-token scope, ASCII, ≤ 72): `chore: Sprint 2 boundary cleanup and audit findings`.
  - Each Bucket A finding becomes one or more Conventional-Commits-scoped commits.
  - The PR description lists every finding and its disposition (fixed / backlogged-to-milestone / accepted), states which Sprint-3 stories are unblocked, ticks the four-invariant checklist with rationale (most likely "N/A — audit cleanup"), and records the per-scope before/after coverage line (or "N/A" for docs-only).

If Bucket A is empty: commit the `docs/audits/sprint-2/` reports as a docs-only PR (which, under the #77 change detection, runs only the title lint).

For Bucket B items: each is a GitHub issue on its owning **milestone**; the PM maintains the list at `docs/audits/sprint-2/06-deferred-to-sprint-3.md`.
For Bucket C items: an ADR entry or a retro note.

────────────────────────────────────────
PHASE 8 — SPRINT 3 KICKOFF READINESS CONFIRMATION
────────────────────────────────────────

Owner: pm (writes) + qa (signs off).

After the cleanup PR (if any) merges, the PM produces `docs/sprint-zero/sprint-3-kickoff-readiness.md` (and, if the team wants a dedicated plan, a `sprint-3-plan.md` mirroring `sprint-2-plan.md`):
  - Confirmation that all five audit phases are resolved (every Bucket A fixed, every Bucket B filed on a milestone, every Bucket C accepted).
  - The first three Sprint-3 PRs queued in `next-three-prs.md` with story files and DoR-compliance noted; the Sprint 3 milestone populated with the Groups stories.
  - The Sprint-3 first PR (FR-GR-01 Create group) identified by name and unblocked.
  - QA reviews and posts a sign-off comment.

This file is the green light to start Sprint 3.

Reconcile the planning docs at this session's close: `sprint-2-plan.md` (mark Sprint 2 fully closed; #77 merged, velocity-excluded, Total unchanged 142 / 34) and `next-three-prs.md` (add the cleanup-PR or audit-PR row; flip the Sprint-3 Groups epic to the next-up candidate).

────────────────────────────────────────
EXECUTION PROTOCOL
────────────────────────────────────────

Phase by phase, stop after each, wait for "proceed" before the next. Phases 1–5 produce audit reports under `docs/audits/sprint-2/`. Phase 6 triages. Phase 7 acts on the triage (open the cleanup PR or commit the audit reports as a docs-only PR). Phase 8 confirms Sprint-3 readiness. Refuse any attempt to start the Sprint 3 Groups epic, the `go_router` migration, or any feature work inside this audit session.
