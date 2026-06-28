# Phase 4 — Infra, Dependency, and Deploy Audit

**Owner:** DevOps (lead) + Architect (consulting)
**Scope:** PreToolUse hooks, dependency posture, the nightly deploy pipeline, and CI-gate
completeness.
**Status:** one HIGH finding (DC-12/DC-13 gates are not required checks) routed to the repo
owner; the rest PASS or accepted.

---

## 4.1 Hook firing

The three PreToolUse invariant guards (`.github/hooks/hooks.json`) are correctly scoped and
sound:

| Hook | Scope | Invariant |
|---|---|---|
| `block-simplified-balances-write` | files under `lib/` (client code) | 2 — server-maintained projection |
| `block-platform-share-targets` | `*.dart` / `*.yaml` / `*.yml` | 3 — system share sheet only |
| `block-second-firebase-project` | `.firebaserc`/`firebase.json`, `scripts/**`, `.github/workflows/*.yml` (firebase CLI must pin `--project`) | 4 — single project |

A visual sprint rarely trips them, and there is no evidence of a false positive (no legitimate
reskin edit was blocked) or false negative (no boundary slipped) across the DC PRs or this
session — every edit in this session succeeded. The `nightly-deploy.yml` added in #142 pins
`--project` on its single `firebase deploy`, satisfying `block-second-firebase-project` (the
workflow comment notes this explicitly).

**Float/double status:** no `double` money math exists in the reskinned widgets — the only
`double` occurrences in the changed widgets are layout dimensions (`size`, `width`, `height`,
`diameter`). The double-money prohibition is enforced by the expenses **boundary-contract**
grep test (forbidding the literal `double ` in `lib/features/expenses/**.dart`), not a
PreToolUse hook; that contract still holds (the affected-area test run is green). **PASS.**

---

## 4.2 Dependencies

- **`pubspec.lock` is intact** (git-clean this session) and resolves against the fvm-pinned
  Flutter 3.44.3 / Dart 3.12 — no bare-`pub get` downgrade crept in.
- **`ios/Podfile.lock` unchanged** — consistent with `fl_chart` being pure-Dart (it adds no
  CocoaPods plugin; only native/Firebase plugins move the lock, intentionally, in earlier
  sprints).
- **`flutter pub outdated`:** routine version drift only — minor patch bumps available for the
  `firebase_*` plugins (e.g. `firebase_auth 6.5.2 → 6.5.4`, `firebase_core 4.10.0 → 4.11.0`) and
  larger pending majors (`flutter_riverpod 2.x → 3.x`, `very_good_analysis 6 → 10`,
  `google_fonts 6.3.3 → 8.1.0`, `share_plus 10 → 13`). **None security-critical**; none
  introduced by Sprint 3.
- **`npm audit` (functions/):** **34 advisories — 2 low, 32 moderate, no HIGH/CRITICAL.** All are
  transitive in the `firebase-admin` → `@google-cloud/firestore` → `google-gax`/`teeny-request`
  → `uuid` tree; `functions/package*.json` is unchanged by Sprint 3 (a visual sprint). No fix
  exists short of a major `firebase-admin` bump, which is out of scope for this cleanup.

| Finding | Severity | Action |
|---|---|---|
| `firebase_*` minor patch bumps + functions moderate/low transitive advisories | Low | **Backlog** — a dedicated dependency-refresh pass (its own project) |
| `pubspec.lock` / `Podfile.lock` integrity | — | PASS |

---

## 4.3 The nightly deploy pipeline (#110 / #142)

`.github/workflows/nightly-deploy.yml` is **single-Firebase-project compliant (Invariant 4)** and
scoped correctly:

- A **"Verify single Firebase project (Invariant 4)"** step fails the run if `.firebaserc` has
  anything other than exactly one project.
- The deploy is `firebase deploy --only firestore:rules,firestore:indexes,storage --project
  onebytwo-avtanshgupta --non-interactive` — **every call pins `--project`**, and it deploys
  **only** the declarative rulesets + indexes. **Cloud Functions are explicitly NOT deployed**
  here (they ship via the tagged `release.yml`), closing the #110 drift (which also added
  `storage` that the release pipeline historically omitted).
- `concurrency: firebase-prod-deploy` (`cancel-in-progress: false`) prevents overlap with a
  release deploy; the `production-firebase` environment provides the gated service-account
  secret; triggers are the nightly cron (18:30 UTC = 00:00 IST) + `workflow_dispatch`.

**Observation (not a code defect):** no run is recorded yet (`gh run list` for *Nightly Backend
Sync* is empty) — the pipeline is scheduled but **unverified-green**. **Recommend the owner
trigger one `workflow_dispatch` run** to confirm the service-account secret + deploy path before
relying on the unattended cron. **PASS (wiring); verify-green recommended.**

---

## 4.4 CI gate completeness — FINDING (HIGH)

The `pull-request` ruleset (id `15802807`, **active**) requires these status checks:

- Cloud Functions Lint & Test · Flutter Lint & Test · Build Android (debug) · Build iOS (no
  signing) · PR Title Lint · Integration Tests (Emulator Suite) · Coverage Gate (SRS 5.7)

**Missing from the required set: "Golden & A11y Checks" (`golden-a11y-checks`, DC-13) and
"Accessibility Gate (WCAG AA)" (`a11y-checks`, DC-12).** Those jobs run on every PR but are **not
required**, so a PR could merge with a failing or skipped golden/contrast/dynamic-type gate — the
visual-regression and accessibility guarantees the whole Sprint 3 was built to enforce can be
bypassed at the merge button. The ruleset was evidently not updated when DC-12/DC-13 added the
jobs (#139/#140/#141).

The job logic itself cannot be bypassed via `workflow_dispatch` (the compare job skips dispatch —
the #141 fix — and `golden-refresh` owns the dispatch authoring path), so the gap is purely the
**required-check registration**, not the job wiring.

| Finding | Severity | Action | Owner |
|---|---|---|---|
| `golden-a11y-checks` + `a11y-checks` not in the ruleset's required checks | **High** | Add both contexts to ruleset `15802807` required checks | **Repo owner** (repo-settings change, not a PR code change) |

This is a **repo-settings change**, not a code change in the cleanup PR — so it is routed to the
owner as a required action (and tracked as a Bucket-B issue at Phase 7). It does not block the
cleanup PR but should be applied before Sprint 4 opens so Groups inherits enforced gates.

---

## Dispositions

| Bucket | Items |
|---|---|
| **A — fix now (owner action)** | Add `golden-a11y-checks` + `a11y-checks` to the required-checks ruleset (repo setting; cannot be done in a PR). |
| **B — backlog** | Dependency-refresh pass (`firebase_*` patch bumps + functions moderate/low transitive advisories); a `workflow_dispatch` verification run of the nightly deploy. |
| — | 4.1, 4.3 (wiring), and lock integrity are PASS. |

**Verification:** hooks read and sound; `pubspec.lock`/`Podfile.lock` git-clean; `npm audit` =
34 moderate/low (no high/critical); ruleset required-checks enumerated via `gh api`.
