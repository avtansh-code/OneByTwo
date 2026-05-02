# Sprint 1 Retrospective

**Date:** 2026-05-02
**Sprint:** 1
**Velocity:** 43 SP / 10 PRs (7 feature, 1 setup, 2 fix-up)

---

## What Worked

1. **Agentic workflow with specialist agents.** The division of labour across PM,
   Architect, Flutter Dev, Functions Dev, QA, and DevOps agents kept each PR
   focused. Handoff contracts between agents were respected throughout the sprint.

2. **Test-first discipline caught issues early.** Writing tests before or alongside
   implementation surfaced validation edge cases (phone number prefixes, OTP retry
   limits, empty display name) before they reached QA. The canonical six-case test
   matrix for FUNC-01 locked the simplified-debts contract cleanly.

3. **Feature PR conventions from PR #4 onwards.** The patterns established in
   PR #4 (branch naming, commit message format, PR description template, review
   checklist) were ratified in PR #5 and followed consistently for the remainder
   of the sprint. This reduced review friction.

4. **CI pipeline caught real issues.** The PR pipeline detected the Firestore rules
   test race condition (parallel Jest workers conflicting on emulator state) and
   the iOS build failure before either reached main. Both were fixed in-sprint.

---

## What Was Friction

1. **Rules test parallelism bug (PR #12 fix).** Jest running Firestore rules tests
   in parallel caused intermittent failures because multiple test suites were
   writing to the same emulator instance concurrently. The fix was to set
   `maxWorkers: 1` in `jest.rules.config.js`. This cost debugging time and should
   have been anticipated given the single-emulator constraint (invariant 4).

2. **iOS CI runner instability (`macos-latest` changing).** GitHub Actions'
   `macos-latest` label shifted mid-sprint, causing Xcode version mismatches in
   the iOS build step. This produced a transient CI failure that was not
   immediately obvious. Pinning to a specific runner version would have prevented
   this.

3. **Profile placeholder pattern required updating many test fakes when
   UserRepository changed.** Adding methods to `UserRepository` for profile
   features (PR #10, #13) required updating every test file that used a fake or
   mock of that repository. The boilerplate overhead grew noticeably and will
   compound as more repository methods are added in Sprint 2.

---

## Velocity

- **43 SP** delivered across **10 PRs** (7 feature, 1 setup, 2 fix-up).
- This is the first sprint. It establishes data point one of N. Sprint 2
  comparison will determine whether 43 SP per sprint is a sustainable pace or
  an outlier inflated by the relatively straightforward nature of auth and
  infrastructure stories.
- No stories were carried over. All 11 planned stories were shipped within the
  sprint boundary.

---

## Fix-Up Rate

- **2 fix-up PRs** across Sprint 1: PR #8 and PR #9, both addressing the iOS
  Phone Auth crash.
- PR #8 was an initial fix attempt; PR #9 was the complete resolution that also
  addressed an analytics type error surfaced during the same investigation.
- A fix-up rate of 2/10 (20%) is acceptable for a first sprint where CI patterns
  and platform-specific behaviour were still being established. This metric is
  worth monitoring in Sprint 2 — if it remains above 15%, the team should
  investigate whether pre-merge testing on iOS is adequate.

---

## Action Items for Sprint 2

1. **Extract a shared `FakeUserRepository` base class** to reduce boilerplate when
   new methods are added to `UserRepository`. Currently every test file with a fake
   must be updated individually. A base class with default no-op implementations
   would localise the change to one file.

2. **Pin macOS CI runner version explicitly (`macos-15`)** rather than using
   `macos-latest`. This prevents mid-sprint breakage from GitHub Actions label
   updates and ensures Xcode version consistency.

3. **Keep `jest.rules.config.js` `maxWorkers: 1` for rules tests.** This is a
   deliberate constraint, not a workaround. Document it in
   `functions/README.md` so future contributors do not inadvertently re-enable
   parallelism.

4. **Review whether `ProfilePlaceholderScreen` can be removed.** It was introduced
   as a temporary navigation target before the full `ProfileScreen` existed. Now
   that FR-PR-01 has shipped a complete profile view and edit screen, the
   placeholder may be dead code. Confirm and remove if so.
