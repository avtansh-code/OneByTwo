You are the OneByTwo orchestrator agent. Sprint 1 testing is complete: 294 automated tests passing across Flutter unit/widget (213), Cloud Functions (32), Firestore + Storage rules (44), Flutter integration (5), plus lint/format/analyse clean; 49/49 manual tests passing on iOS Simulator. PR #29 is the OTP resend hotfix (one-line E.164 format fix), open for merge.

Three non-cosmetic findings remain. This PR addresses all three before Sprint 2 (Friends epic) opens with PR #15. Title: `chore: post-testing fixes — boundary contracts, emulator project enforcement, and coverage gate`.

Read before starting:
  - `.github/copilot-instructions.md`
  - `.github/shared/invariants.md`
  - `.github/shared/decision-log.md` (current ADRs through ADR-0012)
  - `docs/patterns/feature-pr-conventions.md`
  - `.github/hooks/pre-tool-use/block-second-firebase-project.sh` (current implementation, hardened in PR #14)
  - `.github/workflows/pr.yml` (the current PR pipeline — coverage runs but is not enforced as a gate)
  - `lefthook.yml` (current pre-push config)
  - `scripts/firebase/` (existing emulator scripts)
  - SRS §5.7 (the coverage thresholds — ≥70% non-UI per feature, ≥50% overall)
  - `docs/design/08-plan/definition-of-ready-and-done.md` (DoD §2 already references these thresholds)
  - The PR #29 hotfix (read the diff to understand the exact contract violation)
  - `docs/audits/sprint-1/06-deferred-to-sprint-2.md` (so we don't accidentally duplicate work already queued there)

────────────────────────────────────────
SCOPE — WHAT GOES IN THIS PR
────────────────────────────────────────

Three fixes, all narrowly scoped. ONLY these.

═══ FIX 1 — Boundary-contract test pattern in feature-pr-conventions.md ═══

The conventions doc currently mandates unit/widget/integration test layers but does not specifically call for tests that validate the FORMAT of arguments crossing module boundaries.

The OTP resend bug surfaced because:
  - `OtpEntryController.resend()` passed raw 10-digit phone number to the auth repository.
  - `OtpEntryController.submit()` (and the original `requestOtp()` flow) passed E.164-formatted (`+91XXXXXXXXXX`) numbers.
  - The repository accepted both because the parameter type was `String`.
  - No test asserted what format the argument was in at the boundary.

The pattern fix: add a "Boundary-Contract Tests" subsection under §3 (Test Discipline) of the conventions doc requiring that every controller-to-repository boundary AND every repository-to-Firebase-SDK boundary have at least one test that asserts the format/shape of arguments at the boundary.

The pattern fix MUST include a worked example using the auth controller/repository as the canonical reference. Show:
  - The bug-revealing test that *would* have caught the OTP resend issue (asserts the repository receives `'+91XXXXXXXXXX'`, not `'XXXXXXXXXX'`).
  - Why this is different from a state-transition test.
  - The general rule: if a function takes `String`, `Map<String, dynamic>`, or any loosely-typed argument that has structure, write at least one test that asserts the structure at the boundary.

The pattern fix MUST also acknowledge the related risk — coverage-gate gaming (tests that execute without asserting meaningful behaviour) — in a short note. The fix is not a new test type, it's the discipline of writing assertion-rich tests; the boundary-contract pattern is one example of that discipline.

═══ FIX 2 — Emulator project ID enforcement ═══

Three coordinated changes:

2a. Wrapper script `scripts/dev/start-emulators.sh`:
    - Wraps `firebase emulators:start` with the project ID extracted from `.firebaserc` baked in.
    - Reads the project ID via `jq` so the script and `.firebaserc` never drift.
    - POSIX-compatible, executable, idempotent. Prints "Starting emulators with project: <id>" before invoking.
    - Refuses to run if `.firebaserc` lacks a `default` alias, OR if the default alias is `demo-*` (which would be the misconfiguration this PR is preventing).
    - However: the wrapper allows `--project demo-*` to be passed on the command line as an explicit override (with a warning printed) — Firebase has a legitimate convention where `demo-*` project IDs run fully-offline emulators, and we should not block that intentional use case. The architect should confirm this stance; if rejected, hard-fail on `demo-*` everywhere.
    - Forwards any additional args to `firebase emulators:start`.

2b. Developer documentation update at `scripts/dev/README.md` (create if absent) and a one-paragraph addition to the project root `README.md`:
    - "Always use `scripts/dev/start-emulators.sh`, never raw `firebase emulators:start`."
    - One-paragraph rationale referencing Invariant #4 and the Sprint 1 testing finding.

2c. Hook extension at `.github/hooks/pre-tool-use/block-second-firebase-project.sh`:
    - Currently the hook checks source files for new project IDs. Extend it to also reject:
        * Shell scripts under `scripts/` that invoke `firebase emulators:start` or `firebase deploy` WITHOUT a `--project` flag whose value matches `.firebaserc`'s default alias.
        * GitHub Actions workflow YAML where `firebase` CLI is invoked without an explicit `--project` matching `.firebaserc`.
    - Exclusion: `scripts/dev/start-emulators.sh` is allowed because it IS the canonical wrapper.
    - The hook must continue passing on all currently-merged code (run it against `main` to verify zero false positives).
    - Test the extension explicitly: write a fake `scripts/dev/bad-script.sh` that invokes `firebase emulators:start` without `--project`, verify the hook rejects it; then delete the fake.

═══ FIX 3 — Coverage gate enforcement ═══

Two enforcement points, both as hard gates, plus one conventions-doc update.

3a. Coverage thresholds (verbatim from SRS §5.7):
    - Per-feature folder: `lib/features/<feature>/**` must be ≥70%.
    - Per-module folder: `functions/src/<module>/**` must be ≥70%.
    - Overall repo (Flutter): ≥50%.
    - Overall (Cloud Functions): ≥50%.
    - The simplified-debts module retains its 100% branch-coverage gate from PR #11; this gate is unchanged.

3b. lefthook pre-push gate (`lefthook.yml`):
    - Add a `pre-push` job that runs coverage ONLY on the feature folders touched by the push (not the full suite, to keep push-time tolerable).
    - Implementation strategy: detect which `lib/features/<feature>/**` and `functions/src/<module>/**` folders contain modified files in the push range; run scoped tests for each; assert per-folder ≥70%.
    - Skips gracefully if the push touches no feature folders (pure docs change, root config tweak).
    - Hard fail on threshold breach. Standard `git push --no-verify` escape hatch is documented in the dev README.
    - Include a one-line preamble printed to the developer: "Running scoped coverage gate on touched features. Use --no-verify if you genuinely need to bypass."

3c. GitHub Actions PR pipeline gate (`.github/workflows/pr.yml`):
    - This is the authoritative, blocking gate. lefthook is the early-warning layer.
    - Add a `coverage-gate` job that runs after the existing test jobs:
        * Runs `flutter test --coverage` for the full Flutter suite.
        * Runs `cd functions && npm test -- --coverage` for the Cloud Functions suite.
        * Parses both coverage reports.
        * Asserts each `lib/features/<feature>/**` folder is ≥70%.
        * Asserts each `functions/src/<module>/**` folder is ≥70%.
        * Asserts overall Flutter coverage ≥50%.
        * Asserts overall Cloud Functions coverage ≥50%.
        * Confirms `functions/src/simplified-debts/**` retains 100% branch coverage.
        * Fails the job (and therefore the PR check) on any breach, with a clear log message naming the offending folder and the actual vs expected percentages.
    - The job uses `lcov` for Flutter coverage parsing and Istanbul (`nyc` or built-in Jest output) for Cloud Functions. Coverage report files are uploaded as artifacts so reviewers can see the per-file breakdown.
    - The job must be a REQUIRED status check on `main`, configured via branch protection. Devops verifies and adds documentation in `docs/devops/` (create if absent) for how branch protection is configured for this project.

3d. Conventions doc update (`docs/patterns/feature-pr-conventions.md`):
    - Add an "Enforced Coverage Thresholds" subsection to §3 (Test Discipline) explicitly stating both gates and both thresholds.
    - Cross-reference SRS §5.7 and DoD §2.
    - Acknowledge the gaming risk: "Coverage as a number is gameable. Tests that execute code without asserting meaningful behaviour add coverage but not confidence. The boundary-contract pattern (above) is one defence; the discipline is to write tests that actually constrain behaviour, not just touch lines."
    - Note the per-folder enforcement so contributors don't think the overall ≥50% gate gives them slack — every feature folder must independently meet ≥70%.

═══ WHAT IS EXPLICITLY NOT IN THIS PR ═══

  - The S4 cosmetic finding (disabled button vs inline error on profile setup empty-name). Bucket-B / Sprint 2 chore work.
  - The splash-screen-not-visible-on-emulator observation. Environment characteristic; not a bug.
  - Codecov, coveralls, or other external coverage services. Stay GitHub-native; revisit in v1.1+ if visualisation becomes valuable.
  - Mutation testing as an anti-gaming layer. Discussed in the conventions doc but not enforced — far too heavy for v1.0.
  - Adjusting the SRS thresholds. The thresholds are SRS-mandated; this PR enforces them, doesn't redefine them.
  - Any new feature work.
  - Any new ADRs (this PR is small enough that the conventions update and the script/CI changes are self-explanatory).

If during the PR an agent suggests bundling additional findings or proactive fixes, refuse and queue.

────────────────────────────────────────
EXECUTION PROTOCOL
────────────────────────────────────────

The orchestrator delegates:

1. PM agent creates a short story file at `docs/sprint-zero/stories/CHORE-post-sprint1-testing-fixes.md` with SRS §13.2 ACs covering all three fixes. Specifically:
   - "Given a Flutter file at `lib/features/X/` is changed and pushed, when the lefthook pre-push hook runs, then it executes scoped coverage on that feature and fails the push if coverage <70%."
   - "Given a PR is opened that drops `lib/features/auth/**` coverage to 65%, when the PR pipeline runs, then the coverage-gate job fails with a clear message."
   - "Given an agent invokes `firebase emulators:start` without `--project`, when the PreToolUse hook runs, then the invocation is rejected with a clear message naming Invariant #4 and the wrapper script."
   - "Given a controller calls into a repository, when the conventions doc is consulted, then it specifies that boundary-contract tests are required."
   Commits as `docs(stories): post-Sprint-1 testing fixes`.

2. Architect produces the updated `docs/patterns/feature-pr-conventions.md` with three additions:
   - "Boundary-Contract Tests" subsection with the auth-flow worked example.
   - "Enforced Coverage Thresholds" subsection with both thresholds and both gates.
   - The gaming-risk acknowledgement note.
   Verifies the worked example test compiles and passes against the post-PR-#29 codebase.
   Commits as `docs(patterns): boundary-contract tests and coverage-gate enforcement`.

3. DevOps writes `scripts/dev/start-emulators.sh` per Fix 2a. Tests it locally on macOS at minimum.
   Commits as `feat(dev): emulator wrapper enforcing project ID from .firebaserc`.

4. DevOps creates `scripts/dev/README.md` and updates the root `README.md` per Fix 2b.
   Commits as `docs(dev): mandate scripts/dev/start-emulators.sh for local emulators`.

5. DevOps extends `.github/hooks/pre-tool-use/block-second-firebase-project.sh` per Fix 2c. Tests both directions (clean pass on `main`, rejection on a deliberately-bad fake script).
   Commits as `chore(hooks): extend block-second-firebase-project to cover emulator/deploy invocations`.

6. DevOps updates `lefthook.yml` to add the scoped coverage pre-push gate per Fix 3b.
   - Tests that a push touching `lib/features/auth/**` triggers scoped Flutter coverage.
   - Tests that a push touching `functions/src/simplified-debts/**` triggers scoped Functions coverage.
   - Tests that a docs-only push triggers nothing and passes through.
   Commits as `feat(hooks): scoped coverage gate in pre-push`.

7. DevOps updates `.github/workflows/pr.yml` to add the `coverage-gate` job per Fix 3c.
   - Verifies the job runs against the current `main` branch state and PASSES (otherwise the gate is misconfigured or actual coverage is below threshold somewhere — investigate before adding the gate).
   - Documents the branch-protection configuration step in `docs/devops/branch-protection.md`. The architect or human stakeholder must apply the actual branch-protection setting in the GitHub UI; the docs explain how.
   Commits as `feat(ci): coverage gate enforcing SRS §5.7 thresholds`.

8. QA verifies:
   - The wrapper script works on macOS.
   - The hook extension produces zero false positives against `main`.
   - The lefthook coverage gate triggers correctly on touched features and skips on docs-only changes.
   - The CI coverage gate triggers correctly. Actively try to break it: open a draft PR that adds a new feature folder with no tests; verify the gate fails.
   - The conventions-doc updates are internally consistent (worked examples actually catch the bugs they claim to catch; thresholds match SRS verbatim).
   QA posts the explicit DoD §3 sign-off.

9. PR opened by devops:
   Title: `chore: post-testing fixes — boundary contracts, emulator project enforcement, and coverage gate`
   Body must:
     - Cite the testing summary that surfaced these findings.
     - Reference PR #29 (the OTP resend hotfix) as the bug-of-record for Fix 1.
     - Note that PR #29 fixed the symptom; this PR fixes the patterns that allowed the bug class.
     - State explicitly that this PR enforces existing SRS §5.7 thresholds — it does not change policy, it makes existing policy mechanical.
     - Tick the four-invariant checklist with rationale (most "N/A — chore PR with no application logic"; Invariant #4 ticked with "this PR strengthens enforcement").
     - List the three fixes and their files, grouped clearly.
     - Confirm coverage on `main` passes the new gate before adding the gate (otherwise, the gate is being added on top of a broken state — fix coverage first).
     - Confirm hook extension was tested both ways.
     - Confirm lefthook gate was tested with feature-touching, function-touching, and docs-only pushes.
     - End with "Next PR: PR #15 — FR-FR-01 contact picker UI (Sprint 2 opener)."

────────────────────────────────────────
DEFINITION OF DONE
────────────────────────────────────────

Walk the DoD checklist from `docs/design/08-plan/definition-of-ready-and-done.md`:

  - DoD §1: PR follows Conventional Commits, approving review from architect (for the conventions update) and devops (for the tooling and CI).
  - DoD §2: tests passing — including a small new unit test for the wrapper script's project-ID-extraction. Coverage thresholds held (this PR adds tests and a gate; it must not remove coverage). The gate ITSELF passes against `main`'s current coverage, otherwise the gate is being added on top of a broken state.
  - DoD §3: QA sign-off comment posted.
  - DoD §4: telemetry — N/A (chore PR).
  - DoD §5: accessibility — N/A.
  - DoD §6: dark mode — N/A.
  - DoD §7: invariant compliance — Invariant #4 enforcement strengthened; verify the four other invariants are not weakened.
  - DoD §8: documentation updated — `feature-pr-conventions.md`, `scripts/dev/README.md`, project root `README.md`, `docs/devops/branch-protection.md`.
  - DoD §9: no S1/S2 bugs related to this work.

────────────────────────────────────────
PRE-FLIGHT CHECK BEFORE ADDING THE COVERAGE GATE
────────────────────────────────────────

Before committing the lefthook and CI coverage-gate changes, the orchestrator MUST verify the gate would pass on `main`'s current state. Otherwise the PR introduces a hard gate that is broken from day one.

DevOps runs the gate logic locally (or in a draft CI run) against `main` and reports the actual coverage per feature folder and per module. Three outcomes:

  Outcome A: All folders pass ≥70% per-feature, ≥50% overall, simplified-debts at 100% branch.
    → Proceed. Commit the gate changes.

  Outcome B: One or more folders are below 70% but above some lower threshold.
    → STOP. Two options:
        i. Add tests in this PR to bring failing folders above 70% (scope creep, but tractable if the gap is small).
        ii. Open a follow-up coverage-fix PR FIRST, then re-run this PR with the gate added.
    Architect makes the call based on the size of the gap. If the gap is large, option (ii) is correct.

  Outcome C: A folder is below 50% or simplified-debts has dropped from 100%.
    → STOP and escalate to me. This is a more serious finding than the coverage-gate PR's scope; it implies a regression in one of the existing PRs that deserves its own analysis.

Document the pre-flight outcome explicitly in the PR body so reviewers see it.

────────────────────────────────────────
GUARDRAILS
────────────────────────────────────────

If during this PR an agent proposes:
  - "While we're touching the conventions doc, let's also add [some other pattern]" → refuse, separate PR if it's worth doing.
  - "Let's also fix the cosmetic profile-setup S4 finding here" → refuse, that's bucket-B Sprint 2 work.
  - "Let's add Cloud Function deploy enforcement to the hook beyond what's specified" → consider only if the hook extension is trivial; otherwise queue.
  - "Let's rewrite the emulator scripts entirely" → refuse, the wrapper is the minimum surgical fix.
  - "Let's promote this whole thing to a Sprint 2 boundary-cleanup style PR" → refuse, the scope is three findings.
  - "The coverage threshold should be 80% / 90% instead of 70%" → refuse, the SRS is the source of truth and this PR enforces it, not redefines it.
  - "The coverage gate should run on every commit, not every push" → refuse, push-time is correct (commit-time is too noisy and slow).
  - "Let's use Codecov / coveralls instead of doing this in-house" → refuse for v1.0; the in-house gate uses lcov and Istanbul which are standard, and external services add a third-party dependency the project doesn't need yet.
  - "Let's lower the lefthook gate to a warning, not a hard fail" → refuse — but `git push --no-verify` is the documented escape hatch for emergencies, which preserves flexibility without weakening the default.
  - "Let's add a temporary exemption for [some module] so the gate passes" → refuse; if a module can't meet threshold, fix the module's tests, don't soften the gate. The pre-flight step exists specifically to surface this.

If the path forward on a small implementation detail is ambiguous (exact regex for the hook's match logic; exact lcov-parsing approach; whether a particular test file counts as "touched" for scoped pre-push), devops decides and notes the choice in the PR body.

Begin by delegating to PM for the story file.