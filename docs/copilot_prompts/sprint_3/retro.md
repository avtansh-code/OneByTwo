You are the OneByTwo orchestrator agent. **Sprint 3 — the Design Conversion Sprint (the "Direction A — Haldi" visual system, `design_handoff_one_by_two/`) — is complete and its milestone is closed (18 issues, 0 open).** It delivered DC-01..DC-13 (#113–#125: token + type foundation, the six reskinned OBT* widgets, the 11 new Haldi components, the Auth/Home/Friends/Add-expense/Settle-up/Activity/Profile conversions, dark-mode parity, the WCAG-AA re-verification + CI gate, and the golden visual-regression harness), the two trailing issues #128 (foundation §4.1 reconciliation — ADR-0025) and #110 (production deploy-drift — now a nightly rules/indexes/storage deploy pipeline), and the design-fidelity follow-up PR #143 (the one-line balance pill, the home top-balance single-row + tight Settle-Up gap, the dc05/dc06 golden-fixture wrong-state fix, and the Friends-summary rupee-glyph fix). The governing decisions are ADR-0024 (adopt Haldi) and ADR-0025 (§4.1 reconciliation).

This session is the **Sprint 3 → Sprint 4 boundary sweep**: a retrospective and gap audit that **finds every gap left by the Design Conversion and FIXES the ones that matter**, run **before** the Sprint 4 Groups epic (FR-GR-01..07, FR-SE-05..08, FR-EX-06/07 in group context — 13 open issues on the Sprint 4 milestone) opens. It mirrors the `docs/copilot_prompts/sprint_1/retro.md` and `sprint_2/retro.md` precedent, but every phase is tuned to the fact that Sprint 3 was a **visual/UX conversion** (no data-model, security-rule, function, trigger, schema, or telemetry-contract change), so the headline audit dimension is **design fidelity against the Haldi handoff**, not backend correctness.

The stakeholder's directive for this retro is explicit: **find ALL the gaps and, based on the findings, FIX the issues.** Bias the triage toward Bucket A (fix now) — this is a remediation pass, not a report-only audit. A standalone report is the outcome only if the audit genuinely finds nothing fixable.

This session has two possible outcomes:
  - A "Sprint 3 design-conversion cleanup" PR (the next available number, ≥ #144) carrying the fixes the audit identifies — the expected outcome.
  - A standalone audit report set under `docs/audits/sprint-3/` only if no fixes are warranted.

The orchestrator runs the audit first and lets the findings dictate the response; it does NOT pre-commit to one. It does NOT start the Sprint 4 Groups epic in this session.

Read before starting:
  - `.github/copilot-instructions.md`
  - `.github/shared/invariants.md` (the four non-negotiables — re-affirmed, not touched, by Haldi)
  - `.github/shared/decision-log.md` (all ADRs; Sprint 3 added ADR-0024 Haldi adoption and ADR-0025 §4.1 reconciliation)
  - `.github/shared/coding-standards.md`, `.github/shared/handoffs.md`, `.github/shared/test-strategy.md`
  - `.github/shared/milestone-tracking.md` (the milestone lifecycle; Bucket-B findings are filed on a milestone, not a label)
  - `.github/skills/review-pull-request/SKILL.md` (use its design-grounded review dimensions as the audit lens)
  - `design_handoff_one_by_two/` — **the authoritative visual system** (README token table; `screens/Phase1 - Foundations`, `Phase2 - Components`, `Phase3a..g` flows; light + dark, every state). Groups (`Phase3d`) and Marketing (`Phase4`) are OUT of scope (Sprint 4 / not-in-app).
  - `docs/audits/design-conversion/` — the Sprint-3 PLANNING pack (`01-coverage-gap`, `02-conversion-checklist`, `03-foundation-plan` §3 type ramp + §4.1 widget map, `04-qa-test-strategy` §A goldens / §B contrast / §C dynamic-type, README). This is the plan; this retro checks what shipped against it.
  - `docs/copilot_prompts/sprint_3/retro-design-validation.md` — the focused **design-fidelity validation prompt** (the single-line-fit standard + the two confirmed findings). Phase 1 of this retro is its big sibling: run that validation as Phase 1's method, and carry its two findings in as known inputs.
  - `docs/sprint-zero/sprint-3-plan.md`, `docs/sprint-zero/sprint-4-kickoff-readiness.md`, `docs/sprint-zero/next-three-prs.md`.
  - The live harness: `test/golden/golden_harness.dart`, `test/golden/flutter_test_config.dart`, `test/support/widget_test_harness.dart`, and `.github/workflows/pr.yml` (the `golden-refresh`, `golden-a11y-checks`, and `a11y-checks` jobs).

Standing caveats (read first):
  - **PR numbering.** Issues and PRs share one sequential namespace; the cleanup PR lands as the next available number (≥ #144 — highest PR is #143, highest issue is #128). Reconcile the slot label at PR open.
  - **CI title-lint.** `.github/workflows/pr.yml` enforces a single-token conventional-commit scope and an ASCII subject ≤ 72 chars. No em-dash, no comma-separated multi-scope.
  - **Change detection.** A pure-docs PR (touching only `docs/**`) runs only the PR Title Lint; the Flutter/Functions/build/integration/coverage jobs skip. A cleanup PR that touches `lib/**`, `test/**`, the rules, or a workflow re-engages the corresponding jobs.
  - **fvm / SDK.** The fvm wrapper may be broken — use the pinned SDK: `export PATH="/Users/avtanshgupta/fvm/versions/stable/bin:$PATH"` then bare `flutter analyze lib test`, `flutter test`, `dart format .`, and bare `git`/`gh` (Flutter 3.44.x / Dart 3.12.x). `very_good_analysis` is strict (≤ 80-char lines incl. comments, `prefer_const`, `prefer_int_literals`, `avoid_redundant_argument_values`, `directives_ordering`). CI gates on `dart format --set-exit-if-changed .` — run `dart format .` before every push.
  - **Goldens are host-sensitive.** NEVER `--update-goldens` on macOS and commit the bytes. Author baselines ONLY on `ubuntu-latest` via the `golden-refresh` `workflow_dispatch` job: `gh workflow run pr.yml --ref <branch>` → wait for the "Golden Refresh (manual)" job → `gh run download <id> --name golden-baselines --dir /tmp/dl` → `cp -R /tmp/dl/. test/golden/goldens/` → **review every changed PNG as an image** → commit. Multi-tag selection uses the boolean-OR selector (`--tags "golden || a11y-contrast || a11y-dynamic-type"`), never repeated `--tags`. To inspect a render locally, `flutter test <file> --update-goldens --plain-name <name>` then `git checkout test/golden/goldens/` to discard the macOS bytes before regenerating on ubuntu.
  - **British English, no emojis, Conventional Commits, the `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>` trailer.** Merge needs an OWNER approval; wait out iOS (the slowest job). Commit any prompt/report with its PR.

────────────────────────────────────────
PHASE 0 — SCOPE AND OUTPUT FRAMING
────────────────────────────────────────

The orchestrator commits to the framing in writing (produce `docs/audits/sprint-3/00-phase-0-framing.md`):

  - This is a design-conversion AUDIT + REMEDIATION, not feature work. No new features ship; the Sprint 4 Groups epic is NOT started here. Sprint 3 changed the visual/UX layer only — so no finding in this session may alter a Cloud Function, a Firestore/Storage rule, the schema, a trigger, the simplified-debts algorithm, or a telemetry-event contract. A finding that appears to require one is mis-scoped: re-route it to the owning backend area as a Bucket-B issue, do not "fix" it inside this visual cleanup.
  - Findings are triaged into three buckets: (a) **fix now** in the cleanup PR, (b) **backlog** as a tracked issue on the owning milestone (per `.github/shared/milestone-tracking.md` — default Sprint 4; Post-v1.0 for explicitly post-launch items), (c) **accept and document** (an ADR note or a retro line).
  - The bar for "fix now": is it a visible divergence from the Haldi handoff, an accessibility regression, a money-rendering defect (e.g. the rupee-glyph tofu), a one-line component that wraps/truncates, a broken or self-deceiving golden, or anything that would make Sprint 4 inherit a design-debt? If yes, fix now.
  - The bar for "backlog": a non-blocking polish item or a larger divergence whose fix is a project of its own (file it on a milestone, do not leave it silent).
  - The bar for "accept and document": a deliberate, defensible deviation from the handoff (record it against ADR-0024/0025 or in the retro so it is not re-discovered later as a "bug").
  - **Per the stakeholder directive, bias toward Bucket A.** Every finding gets explicitly triaged; none falls into the gap between buckets.

────────────────────────────────────────
PHASE 1 — DESIGN-FIDELITY VALIDATION (THE HEADLINE)
────────────────────────────────────────

Owner: designer (lead) + flutter-dev (implements) + architect (rules on contract-level findings) + qa (re-baselines + signs off).

This is the core of the retro: systematically verify the implemented Flutter app against `design_handoff_one_by_two/` and **fix every divergence that matters**. Run `docs/copilot_prompts/sprint_3/retro-design-validation.md` as the METHOD for this phase — it is the detailed companion. In particular:

1.1  **Build the fidelity matrix.** Enumerate every shared component (Phase2) and every converted screen + state (Phase3a/b/c/e/f/g), each against its handoff reference. For each, the designer does a side-by-side check of: colour token, type family/size/weight, radius, shadow/outline, spacing, icon, **one-line-vs-wrap**, and state coverage (loading / empty / populated / error, light + dark). Record PASS / FINDING per cell in `docs/audits/sprint-3/01-design-fidelity-validation.md` (mirror the existing audit row format: location, divergence, severity, action, owner).

1.2  **The single-line-fit standard (load-bearing).** Every element the handoff draws on one line — every `white-space:nowrap` pill/chip, every amount/balance figure, every row title/subtitle the reference keeps to one line — must render on one line in the app and **scale its text down to fit** (`FittedBox(scaleDown)` + `maxLines:1` + `softWrap:false`), never wrapping to a second line and **never truncating/ellipsising money**. Audit EVERY one-line component, not just the balance pill: category/filter chips, list-tile titles + balances, the net-balance hero amount, the settle-up amount, activity-row amounts, the amount input, summary cards, segment labels, button labels. (#143 already fixed the balance pill, the home top-balance row, and its Settle-Up gap — verify those held and extend the standard app-wide.)

1.3  **The rupee-glyph (₹-in-Hanken) finding (load-bearing, systemic).** Amounts rendered in a Hanken Grotesque text slot show the rupee sign (U+20B9) as a missing-glyph box — the bundled Hanken static instance has no ₹ (verified: Bricolage has it, Hanken does not), and on device the ₹ falls back to a mismatched font. The foundation rule (`03-foundation-plan` §3.3 / ADR-0025) requires amounts to render in Bricolage with tabular figures via an `OBTText.amount*` helper. #143 fixed the Friends summary band; this phase fixes the **remaining confirmed sites**: the add-expense split "Total" (`step_2_split_and_payer.dart`, `titleMedium`), the settle-up-sheet sentence (`obt_settle_up_sheet.dart`, `bodyMedium`), the expense-detail participant row (`expense_detail_screen.dart`), and the settlement-history signed amount (`settlement_history_screen.dart`) — plus any other the matrix surfaces. Grep aid: for every `formatInrFromPaise(...)` render, assert the applied style resolves to an `OBTText.amount*` helper, never a Hanken `textTheme` slot.

1.4  **Foundation-token integrity (§4.1 / ADR-0025).** Re-check the token table (README), the Bricolage/Hanken type ramp and the amount tiers (16 / 32 / 48 — `OBTText.amount` / `amountFocal` / `amountHero`), radii, the marigold hero-shadow and the dark-mode outline separation, and motion / reduced-motion. Confirm DC-02's "formatter conforms / colour reserved for balance" and the §4.1 reconciliation (textTertiary caption contrast, focal-amount sizing, settle-up separation) actually shipped as ADR-0025 records them.

1.5  **Implement the ratified fixes.** Flutter-dev applies them, updating the lockstep widget / contrast / dynamic-type tests; the architect rules on any finding that is a token/component/§4.1 contract change (record as a decision-log note or §4.1 amendment — do not silently relax a gate). Every visual fix re-baselines goldens on ubuntu (see the caveat) and is reviewed as an image.

Deliverable: `docs/audits/sprint-3/01-design-fidelity-validation.md`, plus the Bucket-A fixes staged for the cleanup PR.

────────────────────────────────────────
PHASE 2 — GOLDEN AND ACCESSIBILITY HARNESS HEALTH
────────────────────────────────────────

Owner: qa (lead) + flutter-dev (consulting).

2.1  **Golden harness blind-spots.** Sprint 3 shipped the DC-13 golden harness, but #143 exposed a class of latent bug: a golden can pass while rendering the WRONG state (a fixture re-used a single-subscription `Stream` across both brightness pumps, so the second pump re-listened a consumed stream, threw, and rendered the ERROR screen — the pixel comparator could not tell, because baseline == broken render). Audit EVERY golden fixture (`test/golden/dc0*.dart`) for the same pattern: any single-subscription `Stream.value`/`Stream.error`/`StreamController().stream` built once and reused across the brightness (or width) loop is suspect. Convert to `Stream Function()` builders (fresh per pump). Add the self-validating content guards #143 introduced (`find.text('Something went wrong')` `findsNothing` for non-error states) wherever they are missing, so this class cannot regress silently.

2.2  **A11y gate integrity (DC-12 / #139).** Re-run the `a11y-checks` families: WCAG-AA contrast against the Haldi palette (light + dark), the 2.0× dynamic-type no-overflow checks (390 / 320 dp), the labelled-control walk (`expectAllInteractiveNodesLabelled`), and the tap-target walk (`expectAllTapTargetsMeetMinSize`, 48 dp). Confirm the balance signal stays **colour + icon + label** everywhere (never colour alone) after the Phase-1 fixes, and that the FAB/tooltip semantic-label trap (label must land on the button node, not only a tooltip) is not reintroduced.

2.3  **Golden authoring discipline.** Confirm the goldens were authored on ubuntu (no macOS bytes crept in), the `golden-refresh` job is `workflow_dispatch`-only and the `golden-a11y-checks` compare job correctly skips on dispatch (the #141 fix) and runs on `pull_request`. Flag any baseline whose provenance is unclear.

2.4  **Coverage and pyramid for the visual layer.** Against SRS §5.7 (≥ 70% non-UI per feature/module, ≥ 50% overall) and `test-strategy.md`: did the conversion keep widget-test coverage of the reskinned screens, or did any reskin drop assertions? Is the golden/contrast/dynamic-type tier proportionate (wide unit base, goldens pinning the look, not goldens substituting for behaviour tests)? Spot-check three reskinned screens where a golden exists but the interaction/edge-state widget tests may be thin.

Deliverable: `docs/audits/sprint-3/02-golden-and-a11y-health.md`, plus any fixture/guard fixes staged for the cleanup PR (these are `test/**`, so they re-engage the Flutter job, not a docs-only skip).

────────────────────────────────────────
PHASE 3 — DOCUMENTATION AND DECISION DRIFT
────────────────────────────────────────

Owner: architect (lead) + pm + designer (consulting).

3.1  **Visual-layer docs vs the handoff.** ADR-0024 made `design_handoff_one_by_two/` the authoritative visual system, superseding the OLD visual-layer docs (`docs/design/02-design-system/*`, `04-wireframes/*`, `05-mockups/*`, `06-screen-specs/*`). Confirm those carry the "superseded by Haldi handoff; historical reference" marker and do not silently contradict what shipped. The **backend/data docs (`03-architecture/*`, `07-technical/{firestore-schema,firestore-security-rules,cloud-functions-catalogue,telemetry-plan,state-management}`) must be UNCHANGED** — verify the conversion did not drift them, but do not re-plan them here.

3.2  **Decision-log currency.** Are ADR-0024 (Haldi adoption) and ADR-0025 (§4.1 reconciliation) accurate against what actually shipped? Were any design decisions made implicitly across the DC PRs (the `OBTText` amount-tier helpers, the one-line-pill contract from #143, the inline friend-detail hero vs a pill, the rupee-glyph/Bricolage rule) that should be back-ported as ADR notes or §4.1 amendments so Sprint 4 inherits them as contracts, not folklore?

3.3  **The planning pack vs delivery.** Reconcile `docs/audits/design-conversion/` (the plan) against what shipped: `02-conversion-checklist` (every screen converted?), `03-foundation-plan` §4.1 (every widget mapped?), `01-coverage-gap` (closed?). Note the 11-vs-(11+groups) component split (group components correctly deferred to Sprint 4).

3.4  **Conventions and standards.** Fold any canonical Sprint-3 pattern not yet written down into `coding-standards.md` / `feature-pr-conventions.md`: the goldens-on-ubuntu authoring flow, the `OBTText.amount*`-for-money rule, the single-line-fit `FittedBox` pattern, and the golden-fixture "fresh stream per pump + content guard" rule. Avoid doc-vs-doc drift.

Deliverable: `docs/audits/sprint-3/03-documentation-and-decision-drift.md`. Doc fixes are Bucket A but land in the same cleanup PR (or a docs-only PR if Bucket A is otherwise empty).

────────────────────────────────────────
PHASE 4 — AGENTIC INFRASTRUCTURE, DEPENDENCY, AND DEPLOY AUDIT
────────────────────────────────────────

Owner: devops (lead) + architect (consulting).

4.1  **Hook firing.** Did the PreToolUse hooks (`block-simplified-balances-write`, `block-platform-share-targets`, `block-second-firebase-project`) fire correctly across the DC PRs? A visual sprint should rarely trip them — confirm no false positives blocked legitimate reskin work and no false negative let a boundary slip. Note the float/double hook status (a money-rendering sprint is a good moment to confirm no `double` money math crept into a reskinned widget).

4.2  **New dependencies.** The conversion may have added visual deps (e.g. `fl_chart` for the spend donut, `google_fonts` for Bricolage/Hanken). Run `flutter pub outdated` via the pinned SDK and confirm `pubspec.lock` matches the fvm-pinned SDK (a bare `flutter pub get` on an older system SDK downgrades transitive deps and the `sdks:` floor — if found, restore the committed lock). Confirm any pure-Dart dep (e.g. `fl_chart`) did not change `ios/Podfile.lock`, and any native/Firebase plugin that did is intentional. `npm audit` in `functions/` for completeness (no functions changed, but verify clean).

4.3  **The nightly deploy pipeline (#110 / #142).** Sprint 3 root-caused a production deploy-drift (5/7 functions + stale rules) and added a nightly rules/indexes/storage deploy pipeline (`.github/workflows/nightly-deploy.yml`, single-project-guarded, `--project onebytwo-avtanshgupta`). Confirm it is single-Firebase-project compliant (Invariant 4), passes `--project` on every `firebase` call, deploys only what it claims (rules + indexes + storage rules, never functions silently), and has run (or is scheduled to run) green. Flag any remaining drift between the committed rules/indexes and production.

4.4  **CI gate completeness.** Confirm the `golden-a11y-checks` and `a11y-checks` jobs are wired as required checks and that the DC-13 / DC-12 gates cannot be bypassed by the `workflow_dispatch` path.

Deliverable: `docs/audits/sprint-3/04-infra-dependency-and-deploy.md`.

────────────────────────────────────────
PHASE 5 — SPRINT 4 (GROUPS) PRE-FLIGHT READINESS
────────────────────────────────────────

Owner: pm (lead) + architect + designer.

Sprint 4 is the Groups epic (13 open issues). Verify it can start ON the Haldi system.

5.1  **Design readiness for Groups.** Groups (`Phase3d`) was deferred from DC-03, so the **group Haldi components do not exist yet** (group list item, member row, invite-link card, the group settle-up surfaces). Confirm `design_handoff_one_by_two/screens/Phase3d - Groups` is complete and that the first Sprint-4 PR is the group-component scaffold ON the Haldi tokens — i.e. Groups must be built Haldi-native, never reskinned later. List the missing components so Sprint 4 PR #1 can build them.

5.2  **Story DoR.** Read the first three Sprint-4 stories (FR-GR-01 Create group, then the next two). Are they Definition-of-Ready compliant? Is there a story file under `docs/sprint-zero/stories/`? Cross-check `docs/sprint-zero/sprint-4-kickoff-readiness.md` — does it still hold after this retro's findings?

5.3  **Backend contracts already in place.** The Groups data model, security rules, and simplified-debts entry points were specified in earlier sprints (ADR-0021 shared recompute core; ADR-0022 server-maintained projections are client-read-only; ADR-0023 group invite tokens, 7-day expiry, admin revocation). Confirm those are intact and that Sprint 4 only needs the Flutter feature + the group security-rule activation + the group component set — no new backend ADR is blocked.

5.4  **Telemetry and risk.** Confirm the Groups events are enumerated in `telemetry-plan.md` with PII-bearing group/member identifiers hashed, and that the Groups risks (invite-link expiry/revocation, server-side zero-balance guards for remove/leave/delete, multi-party simplified-debts scale) are on the risk register. These are checks, not changes.

Deliverable: `docs/audits/sprint-3/05-sprint-4-readiness.md`.

────────────────────────────────────────
PHASE 6 — TRIAGE AND DECISION
────────────────────────────────────────

Owner: orchestrator.

Consolidate Phases 1–5 into `docs/audits/sprint-3/00-triage-summary.md`. Categorise every finding:

  Bucket A — Fix now (the cleanup PR): design-fidelity divergences, the remaining ₹-in-Hanken sites, any one-line component that wraps/truncates, wrong-state/blind-spot goldens, a11y regressions, doc/ADR back-ports that Sprint 4 depends on, any deploy drift.

  Bucket B — Backlog: larger divergences whose fix is a project of its own, non-blocking polish. File each as a GitHub issue on the owning milestone (default Sprint 4; Post-v1.0 for post-launch). No deprecated labels.

  Bucket C — Accept and document: defensible deviations from the handoff, recorded against ADR-0024/0025 or in the retro.

Every finding lands in exactly one bucket with a rationale.

────────────────────────────────────────
PHASE 7 — DECIDE: CLEANUP PR OR STANDALONE REPORT
────────────────────────────────────────

Owner: orchestrator.

Expected outcome (the stakeholder asked to fix the gaps): open the cleanup PR (next available number, ≥ #144). Title (single-token scope, ASCII, ≤ 72): `fix: Sprint 3 design-conversion cleanup and audit findings` (or `chore:` if the changes are purely non-functional docs/tests).
  - Each Bucket-A finding becomes one or more Conventional-Commits-scoped commits (`fix(widgets):`, `fix(expenses):`, `test(golden):`, `docs(...)`, ...). Group code + its re-baselined goldens logically.
  - Goldens authored on ubuntu, every changed PNG reviewed as an image; `flutter analyze lib test` clean, `dart format` clean, `flutter test` green (incl. the un-skipped goldens and the `a11y-checks` families), coverage ≥ thresholds.
  - PR body: map each change to its handoff reference (the `Phase2`/`Phase3` spec), list every finding and its disposition (fixed / backlogged-to-milestone / accepted), tick the four-invariant checklist (almost all "N/A — visual/test only; `formatInrFromPaise()` stays the sole paise→INR boundary; `simplifiedBalances` read-only; share-sheet untouched; single project"), note the goldens were regenerated on ubuntu, and link the `docs/audits/sprint-3/` reports.

If Bucket A turns out empty: commit the `docs/audits/sprint-3/` reports as a docs-only PR (runs only the title lint).

For Bucket B: each is a GitHub issue on its owning milestone; the PM maintains `docs/audits/sprint-3/06-deferred-to-sprint-4.md`.
For Bucket C: an ADR note or a retro line.

────────────────────────────────────────
PHASE 8 — SPRINT 4 KICKOFF READINESS CONFIRMATION
────────────────────────────────────────

Owner: pm (writes) + qa (signs off).

After the cleanup PR (if any) merges, the PM updates `docs/sprint-zero/sprint-4-kickoff-readiness.md`:
  - Confirmation that all audit phases are resolved (every Bucket A fixed, every Bucket B filed on a milestone, every Bucket C accepted).
  - The first three Sprint-4 PRs queued in `next-three-prs.md` with story files and DoR noted; the Sprint 4 milestone populated; the first PR (FR-GR-01 Create group, building the group Haldi components first) identified by name and unblocked.
  - QA posts a sign-off comment confirming the Haldi system is fidelity-clean and Groups can be built on it.

Reconcile the planning docs at close: `sprint-3-plan.md` (mark Sprint 3 fully closed; record the cleanup PR and its velocity treatment) and `next-three-prs.md` (add the cleanup/audit row; flip the Sprint-4 Groups epic to next-up).

────────────────────────────────────────
EXECUTION PROTOCOL
────────────────────────────────────────

Delegate through the agent team: designer + flutter-dev own Phase 1 (with architect rulings and qa re-baselining), qa owns Phase 2, architect owns Phase 3, devops owns Phase 4, pm owns Phase 5, orchestrator owns Phases 0/6/7. Phase by phase, stop after each and wait for "proceed" before the next. Phases 1–5 produce reports under `docs/audits/sprint-3/`; Phase 1–2 also stage code/test fixes. Phase 6 triages, Phase 7 opens the cleanup PR (or the docs-only PR), Phase 8 confirms Sprint 4 readiness.

FAILURE / REFUSAL: if any finding's "fix" would alter a Cloud Function, a security/Storage rule, the schema, a trigger, the simplified-debts algorithm, or a telemetry-event contract, it is out of scope for this visual cleanup — re-route it as a Bucket-B issue and refuse to implement it here. If any change would weaken an invariant or the SRS, refuse and quote the section. Determinism is non-negotiable — never commit macOS golden bytes. Convert no Groups screen and start no Sprint 4 feature work in this session. Do not edit `docs/OneByTwo_Requirements_Spec.md`.
