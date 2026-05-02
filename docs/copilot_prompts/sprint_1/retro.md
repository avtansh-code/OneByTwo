You are the OneByTwo orchestrator agent. Sprint 1 is complete: PR #12 (FR-PR-01) has merged, the Sprint 1 retrospective exists at `docs/retros/2025-XX-XX-sprint-1-retro.md`, and `docs/sprint-zero/sprint-1-plan.md` is marked final. Before Sprint 2 starts, we run a boundary cleanup and audit sweep.

This session has two possible outcomes:
  - PR #13: a "Sprint 1 boundary cleanup" PR with the fixes the audit identifies.
  - A standalone audit report under `docs/audits/` if no fixes are needed.

The orchestrator decides which outcome based on what the audit finds. Do not pre-commit to one or the other. Run the audit first; let the findings dictate the response.

Read before starting:
  - `.github/copilot-instructions.md`
  - `.github/shared/invariants.md`
  - `.github/shared/decision-log.md` (all ADRs, especially the ones added during Sprint 1)
  - `docs/patterns/feature-pr-conventions.md`
  - `docs/retros/2025-XX-XX-sprint-1-retro.md` (Phase 7 of PR #12 produced this)
  - `docs/sprint-zero/sprint-1-plan.md` (final state)
  - `docs/sprint-zero/next-three-prs.md`
  - `docs/design/08-plan/sprint-sequence.md` (for Sprint 2 scope)
  - `docs/design/08-plan/dependencies-and-critical-path.md`

────────────────────────────────────────
PHASE 0 — SCOPE AND OUTPUT FRAMING
────────────────────────────────────────

The orchestrator commits to the framing of this session in writing:

  - This is an AUDIT, not feature work. No new features ship in this session.
  - Findings are categorised into three buckets: (a) fix now in PR #13, (b) backlog for Sprint 2 as a chore item, (c) accept and document the current state.
  - The bar for "fix now" is: would this materially affect Sprint 2 quality if left unfixed? If yes, fix now. If no, backlog or accept.
  - The bar for "backlog": would Sprint 2 work create friction with this issue, or is it a follow-up that can wait until a natural moment in Sprint 2 or beyond?
  - The bar for "accept and document": is this a deliberate trade-off, or an acceptable level of imperfection that costs less to live with than to fix? If yes, document the acceptance in the relevant ADR or retro so it does not get re-discovered later as a "bug".

Each finding gets explicitly triaged. None should fall into the gap between buckets.

────────────────────────────────────────
PHASE 1 — DOCUMENTATION DRIFT AUDIT
────────────────────────────────────────

Owner: architect (lead) + pm (consulting).

Read the design docs and compare against what actually shipped across PRs #1–#12. Specifically:

1.1  `docs/design/06-screen-specs/` — for each screen that shipped this sprint (splash, phone-entry, OTP, profile-setup, profile-view-edit, home-placeholder), check whether the spec still describes what was built. Drift can happen in either direction:
     - Implementation diverged from spec (drift: implementation is the new truth, spec needs updating OR the spec was correct and implementation has a bug).
     - Spec described something that wasn't implemented (drift: scope was cut, spec needs an updated note or an explicit deferral marker).

1.2  `docs/design/07-technical/firestore-schema.md` — every field that exists in real Firestore documents now should match the schema doc. Particularly: are there fields the implementation added that aren't in the schema? Are there fields in the schema that the implementation never touched?

1.3  `docs/design/07-technical/cloud-functions-catalogue.md` — does it accurately describe `recomputeSimplifiedBalances` as it actually shipped in PR #11? Does the catalogue have the right entry for the function-boundary error codes?

1.4  `docs/design/07-technical/state-management.md` — does the actual Riverpod provider tree match what's described? Are providers named per the convention?

1.5  `docs/design/07-technical/telemetry-plan.md` — every event that fires in the running code, is it in the plan? Every event in the plan, does it actually fire? Sprint 1 added many events; the plan should match.

1.6  Architectural decisions: were any made implicitly during PRs that should be back-ported as ADRs? Examples to check:
     - The cold-start race fix in PR #10 (the auth-state sealed-union pattern). Was this captured as an ADR or left as architect notes? It is a generic pattern that future state machines will copy.
     - The field-level Firestore rules pattern in PR #12. Was this captured as an ADR or left as architect notes? Same future-replication concern.
     - The Cloud Function module layout from PR #11 (pure-algorithm separated from function-boundary). Was this captured? It is the template for every future function.

1.7  `docs/patterns/feature-pr-conventions.md` (ratified after PR #4) — has it stayed accurate as PRs #6 through #12 shipped? Are there patterns now in use that aren't in the conventions doc?

Produce findings under `docs/audits/sprint-1/01-documentation-drift.md`. Each finding is a row: location, drift description, severity (high/medium/low), recommended action (fix now / backlog / accept), owner.

If any "fix now" findings emerge, the architect produces the doc-update commits in PR #13.

────────────────────────────────────────
PHASE 2 — TEST-SUITE HEALTH CHECK
────────────────────────────────────────

Owner: qa (lead) + flutter-dev + functions-dev (consulting).

This phase examines the test suite as a system, not the tests of any individual story.

2.1  Coverage trend across the sprint:
     - Pull coverage at the end of each Sprint 1 PR (the PR descriptions should record this; if any are missing, mark as a process issue).
     - Plot the trend. Is coverage trending up, flat, or down?
     - For `lib/features/auth/**`, `lib/features/profile/**`, `functions/src/simplified-debts/**`, `firestore.rules`-related tests: what is the current absolute coverage, and how does it compare to the SRS §5.7 thresholds?

2.2  Flaky-test detection:
     - Are there any tests that have failed and re-passed in CI without code changes during Sprint 1?
     - The integration tests against the Firebase Emulator Suite are the most likely culprits. Examine them for race conditions, timing dependencies, ordering assumptions.
     - Any flaky test discovered must be either (a) fixed now, (b) marked with a clear `// FLAKY: see issue #N` comment and an issue filed, or (c) deleted with rationale. Silent flakiness is unacceptable — it erodes trust in CI.

2.3  Test-suite runtime:
     - How long does the full `flutter test` run take?
     - How long does the integration test suite against the emulator take?
     - How long does the Cloud Functions test suite take?
     - Are any of these starting to dominate the PR cycle time? If a single test or test file accounts for >20% of the total runtime, flag it for optimisation.

2.4  Test pyramid balance:
     - Count unit tests, widget tests, integration tests across the codebase.
     - The pyramid should be wide at the unit base and narrow at the integration top. Is it inverted (more integration than unit)? That's a smell — integration tests are slower and harder to maintain.

2.5  Coverage gaps that look like risk:
     - Are there modules with coverage well above the threshold but whose tests don't actually exercise the failure paths? (Numbers can lie.) Spot-check three modules manually: do the tests cover error cases, empty states, edge boundaries?

Produce findings under `docs/audits/sprint-1/02-test-suite-health.md`. Same row format as Phase 1.

If "fix now" findings emerge: flaky tests must always be fix-now (option a, b, or c above). Coverage drops below threshold are fix-now. Slow tests can be backlog. Pyramid imbalance is usually a Sprint 2 chore.

────────────────────────────────────────
PHASE 3 — AGENTIC INFRASTRUCTURE DEBT REVIEW
────────────────────────────────────────

Owner: architect (lead) + devops (consulting).

This phase reviews `.github/agents/`, `.github/skills/`, `.github/hooks/`, `.github/shared/` against actual Sprint 1 PR behaviour.

3.1  Hook firing audit:
     - Across the nine feature PRs, did the PreToolUse hooks (`block-simplified-balances-write.sh`, `block-platform-share-targets.sh`, `block-second-firebase-project.sh`) fire?
     - Of those firings: were any false positives (blocked legitimate work)? Were any false negatives revealed in retrospect (an issue slipped past that the hook should have caught)?
     - PR #11 was the first realistic exercise of `block-simplified-balances-write.sh` (server code legitimately writing to the field, client code forbidden from doing so). Did the hook discriminate correctly?
     - PostToolUse hooks (`dart-format.sh`, `eslint-fix.sh`) — any consistent failures? Any silent skips?

3.2  Agent description accuracy:
     - For each agent under `.github/agents/`, has the actual scope of work matched the description?
     - In particular: did the orchestrator correctly delegate to the right agents, or did work consistently end up with the wrong agent? If the latter, the description is the bug, not the orchestrator's behaviour.
     - Are there responsibilities that emerged during Sprint 1 that no agent's description currently covers? (E.g., "QA reviews the integration test seeding for reproducibility from clean emulator state" — was this implicit, and should it be explicit in the qa agent's description?)

3.3  Skill catalogue:
     - For each skill under `.github/skills/`, was it invoked during Sprint 1? Skills that were never invoked may be dead weight; skills that were heavily used may want refinement based on observed friction.
     - Are there capabilities that came up repeatedly across PRs that should be promoted to a named skill?

3.4  Shared invariants:
     - The four invariants in `.github/shared/invariants.md` — were any tested by an attempted violation during Sprint 1 (whether by an agent or by a human review)? What was the result?
     - Any new invariants that emerged from Sprint 1's design decisions that should be added? (For example: "All Firestore documents with mixed user-authored and server-managed fields use the field-level diff rule pattern" — established in PR #12 — could be a candidate for invariant promotion if it's load-bearing across future collections.)

3.5  Conventions-doc accuracy:
     - `docs/patterns/feature-pr-conventions.md` was ratified after PR #4. PRs #6 through #12 shipped under it. Are there patterns established by those later PRs (e.g., the Cloud Function five-test-layer pattern from PR #11, the field-level rules pattern from PR #12) that should be folded INTO the conventions doc as the canonical reference?

Produce findings under `docs/audits/sprint-1/03-agentic-infrastructure-debt.md`. Same row format.

Hook false positives are fix-now (they slow real work). Hook false negatives are fix-now (they let real bugs through). Description gaps are usually fix-now (they're cheap). Conventions-doc additions are typically fix-now because they amortise over Sprint 2.

────────────────────────────────────────
PHASE 4 — DEPENDENCY AND SECURITY AUDIT
────────────────────────────────────────

Owner: devops (lead).

This is a quick health check, not an exhaustive vulnerability scan.

4.1  Flutter dependencies:
     - Run `flutter pub outdated` and capture the output.
     - For any dependency that has had a major version bump since Sprint 1 began, decide: stay pinned (stable, no need), upgrade in Sprint 2 (chore item), or upgrade now (PR #13 if it affects security or stability).
     - Specifically check the Firebase SDK packages — they're under heavy active development and patch versions can include security fixes.

4.2  Cloud Functions dependencies:
     - `cd functions && npm outdated`.
     - Same triage as 4.1.
     - `npm audit` — capture the output. Any HIGH or CRITICAL advisories require immediate attention. MODERATE advisories are typically backlog. LOW are accept.

4.3  Firestore rules drift:
     - Read `firestore.rules` end-to-end. It has been edited across PRs #3, #9, #11, #12. Does it read consistently as a whole, or does it look like it was assembled by different authors?
     - Are there any rules that became dead (e.g., a permissive rule that's superseded by a stricter one elsewhere)?
     - Is the file getting close to a length where it should be split into includes? (Generally not until ~500 lines, but flag for awareness.)
     - Any rule that doesn't have a corresponding negative test in `functions/test/firestore-rules/`? If yes, list them.

4.4  Storage rules drift:
     - Same review for `storage.rules`.

4.5  Secrets and environment:
     - Are there any new credentials needed for Sprint 2 that aren't yet in GitHub Actions secrets? (Sprint 2 is the Friends epic — likely no new secrets, but confirm.)
     - Are any existing secrets approaching rotation thresholds? (For most Firebase secrets, no rotation is required; for App Store Connect API keys and Play Service Accounts, periodic rotation is good hygiene.)

Produce findings under `docs/audits/sprint-1/04-dependency-and-security.md`.

HIGH/CRITICAL npm audit findings are fix-now. Major Firebase SDK upgrades are usually fix-now if they include patch fixes, otherwise Sprint 2. Rules drift is fix-now if there's a real inconsistency, backlog if it's stylistic.

────────────────────────────────────────
PHASE 5 — SPRINT 2 PRE-FLIGHT READINESS
────────────────────────────────────────

Owner: pm (lead) + architect + designer.

Sprint 2 is the Friends epic per `docs/design/08-plan/sprint-sequence.md`. Verify it can actually start.

5.1  Sprint 2 scope clarity:
     - Read the Sprint 2 plan in `docs/design/08-plan/sprint-sequence.md`.
     - Identify the first three stories. Are they Definition-of-Ready compliant per `docs/design/08-plan/definition-of-ready-and-done.md`?
     - For the first story specifically (likely FR-FR-01 friend-add via contact picker): is there a story file in `docs/sprint-zero/stories/`? Is the screen spec at `docs/design/06-screen-specs/` complete? Are wireframes and mockups in place?

5.2  Design artefacts:
     - The Friends epic introduces several new screens (friends list, add friend, friend detail). Are all wireframes and screen specs present and complete?
     - Are component-catalogue entries in `docs/design/02-design-system/components.md` present for any new components the Friends epic introduces (e.g., FriendListItem, ContactPickerRow, BalancePill if not already present)?

5.3  Technical readiness:
     - Friends introduce the `friendships/{friendshipId}` collection. Is the schema in `firestore-schema.md` complete? Are the Firestore rules for friendships outlined in `firestore-security-rules.md`?
     - The friend-add flow uses the contact picker, which requires platform permissions on iOS and Android. Are the permission strings and entries documented anywhere? If not, the architect adds them now (Info.plist `NSContactsUsageDescription`, Android permissions block).
     - The simplified-debts function from PR #11 will be wired to expense triggers eventually, but Sprint 2 is Friends, not Expenses. Confirm Sprint 2 does not actually exercise the simplified-debts function — Friends without expenses means balances are zero throughout Sprint 2. Note this so the team isn't surprised.

5.4  Telemetry plan:
     - Are events for the Friends epic enumerated in `telemetry-plan.md`? At minimum: `friend_added`, `friend_invite_sent`, `friend_search_started`, `contact_permission_granted`, `contact_permission_denied`.

5.5  Risk register:
     - Contact-picker permissions are a notorious source of friction (iOS permission denial UX, Android permission group changes across OS versions). Add Friends-specific risks to `risks-revisited.md` or the Sprint 2 plan.
     - Privacy concerns: importing contacts touches PII. Confirm the privacy policy and SRS §5.5 compliance posture covers this — the user's contacts should NOT be uploaded to Firestore, only matched locally against existing OneByTwo users.

Produce findings under `docs/audits/sprint-1/05-sprint-2-readiness.md`.

Anything that would block Sprint 2's first PR is fix-now. Anything that would block the second or third Sprint 2 PR is also fix-now (because nothing is gained by deferring it). Items that are Sprint 2 Internal cleanup are backlog.

────────────────────────────────────────
PHASE 6 — TRIAGE AND DECISION
────────────────────────────────────────

Owner: orchestrator.

Consolidate findings from Phases 1–5. Categorise every finding:

  Bucket A — Fix now (PR #13):
    - All findings that meet the "would this materially affect Sprint 2 quality if left unfixed" bar.
    - All hook false positives or false negatives.
    - All HIGH/CRITICAL security advisories.
    - All "Sprint 2 first PR is blocked without this" items.
    - All architectural-decision back-ports if they're load-bearing.

  Bucket B — Backlog for Sprint 2 chore:
    - Stylistic inconsistencies.
    - Optimisations.
    - Non-blocking convention updates.
    - Future-state documentation that doesn't affect Sprint 2 quality.

  Bucket C — Accept and document:
    - Deliberate trade-offs that should be acknowledged in an ADR or retro so they don't get re-discovered.
    - Items where the cost of fixing exceeds the cost of living with it.

Produce `docs/audits/sprint-1/00-triage-summary.md` listing every finding with its bucket assignment and rationale.

────────────────────────────────────────
PHASE 7 — DECIDE: PR #13 OR STANDALONE REPORT
────────────────────────────────────────

Owner: orchestrator.

If Bucket A is non-empty: this becomes PR #13. Title: `chore: Sprint 1 boundary cleanup and audit findings`.

If Bucket A is empty: no PR is opened. The audit reports under `docs/audits/sprint-1/` are committed as a small docs-only PR (or fold them into the next chore PR if more comfortable).

For PR #13:
  - Each Bucket A finding becomes one or more commits, with Conventional Commits messages scoped to what's being fixed.
  - The PR description lists every finding and its disposition (fixed-in-this-PR / deferred-to-backlog / accepted-and-documented).
  - The PR description explicitly states which Sprint 2 stories are now unblocked by these fixes.
  - The four-invariant checklist is ticked with rationale (most likely "N/A — audit cleanup, no application logic").
  - PR follows `docs/patterns/feature-pr-conventions.md` (with the chore exemption — chore PRs do not need to cite the conventions doc, but should follow its PR template shape).

For Bucket B items: file each as a GitHub issue tagged `sprint-2-chore` with a link to the audit finding. PM agent maintains a list at `docs/audits/sprint-1/06-deferred-to-sprint-2.md` so they don't get lost.

For Bucket C items: each one gets either an ADR entry in `.github/shared/decision-log.md` (if it's an architectural acceptance) or a note in the relevant retrospective document.

────────────────────────────────────────
PHASE 8 — SPRINT 2 KICKOFF READINESS CONFIRMATION
────────────────────────────────────────

Owner: pm (writes) + qa (signs off).

After PR #13 (if any) is merged, PM produces `docs/sprint-zero/sprint-2-kickoff-readiness.md`:

  - Confirmation that all five audit phases have been resolved (every Bucket A finding fixed, every Bucket B logged, every Bucket C accepted).
  - The first three Sprint 2 PRs are queued in `next-three-prs.md` with story files and DoR-compliance noted.
  - The Sprint 2 first PR is identified by name and is unblocked.
  - QA has reviewed and posts a sign-off comment.

This file is the green light to start Sprint 2.

────────────────────────────────────────
EXECUTION PROTOCOL
────────────────────────────────────────

Phase by phase, stop after each, wait for "proceed" before the next. Phases 1–5 produce audit reports. Phase 6 triages. Phase 7 acts on the triage (open PR #13 or commit the audit reports as a docs-only PR). Phase 8 confirms readiness.

Begin with Phase 0 — commit to the framing.