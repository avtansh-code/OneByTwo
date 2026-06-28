# Phase 2 — Golden and Accessibility Harness Health

**Owner:** QA (lead) + Flutter Dev (consulting)
**Scope:** the DC-13 golden harness (`test/golden/`), the DC-12 accessibility gate, the
golden authoring discipline, and the visual-layer test pyramid.
**Status:** one Bucket-A test-hardening fix staged (content guards on dc07/dc08/dc09); the
remainder verified PASS.

---

## 2.1 Golden harness blind-spots (the #143 bug class)

The #143 follow-up exposed a latent failure mode: a single-subscription `Stream`
(`Stream.value`/`Stream.error`/`StreamController().stream`) built **once** and reused across
the brightness (or width) loop is consumed by the first pump and throws
"Stream already listened" on the second — silently rendering the **error** screen, which the
pixel comparator cannot distinguish (a baseline authored from the broken render matches it).

**Every fixture audited:**

| Fixture | Data-provision shape | Reuse across loop? | Verdict |
|---|---|---|---|
| `dc05_home` | `Stream<…> Function()` builders + `_expectState` guard | fresh per pump | **SAFE** (the #143 fix) |
| `dc06_friends` | `Stream<…> Function()` builders + guard | fresh per pump | **SAFE** (the #143 fix) |
| `dc04_auth` | `Widget Function() build` + `overrideWithValue` fakes | `build()` fresh per pump | **SAFE** |
| `dc07_expenses` | state maps **inside** the brightness loop; re-runnable `Future` fns + immutable `AsyncValue` | fresh per brightness, pumped once | safe from reuse; **guard added** |
| `dc08_settlements` | state maps inside the loop; fresh `FakeSettlementRepository` per brightness | fresh per brightness, pumped once | safe from reuse; **guard added** |
| `dc09_activity` | state maps inside the loop; fresh `FakeActivityFeedRepository` per brightness | fresh per brightness, pumped once | safe from reuse; **guard added** |
| `dc10_profile` | per-`testWidgets` fresh widgets; `(ref) => Stream.value` re-run per container | no reuse loop | **SAFE** |
| `haldi_components`, `obt_widgets_reskin`, `foundation_showcase` | static component galleries; `build()` per brightness, no async data | n/a | **SAFE** |

**Finding (fixed):** dc07/dc08/dc09 render an `error` state in their state maps but **lacked
the self-validating content guard** #143 introduced — so a non-error state that silently fell
through to the error screen would still be blessed. A shared
`expectGoldenState(key, errorText:)` helper was added to `golden_harness.dart` and wired into
the three error-bearing loops with the correct per-screen copy:

- `dc07` expense-detail → `'Could not load expense'`
- `dc08` settlement-history → `'Something went wrong'`
- `dc09` activity-feed → `'Something went wrong'`

The guard asserts the error screen renders **only** for `key == 'error'` and is absent for
every other state. Verified by running the three fixtures with `--update-goldens` (so the byte
comparison passes and only a guard failure could fail the run): **47 cases pass**; the
regenerated macOS bytes were then discarded (`git checkout`/`git clean`) so only the ubuntu
baselines remain committed.

No remaining single-use-stream reuse exists anywhere in the harness.

| Location | Finding | Severity | Action | Owner |
|---|---|---|---|---|
| `dc07/dc08/dc09` error-bearing loops | no content guard against silent error-screen fall-through | Medium | **Fix now** — add `expectGoldenState` guard | QA |

---

## 2.2 A11y gate integrity (DC-12 / #139)

Re-ran the accessibility families against the Phase-1 changes:

- `flutter test --tags "a11y-contrast || a11y-dynamic-type"` — **All tests passed.**

Phase-1 changes are font-fallback (`rupeeAware`) and scale-to-fit (`FittedBox`) only — **no
colour changes**, so WCAG-AA contrast (light + dark) is unaffected, and the 2.0× dynamic-type
no-overflow checks (390 / 320 dp) pass (the scale-to-fit additions strengthen them). The
balance signal stays **colour + icon + label** everywhere (Phase-1 touched the money figure's
font/size, never the trio). No FloatingActionButton was touched, so the FAB/tooltip
semantic-label trap (label must land on the button node, not only a tooltip) is not
reintroduced. The labelled-control and tap-target walks run in the regular suite and remain
green in the affected-area run (989 passed).

---

## 2.3 Golden authoring discipline

Confirmed from `.github/workflows/pr.yml`:

- `golden-refresh` (**Golden Refresh (manual)**): `if: github.event_name == 'workflow_dispatch'`,
  `runs-on: ubuntu-latest`, `flutter-version: 3.44.3`, runs
  `flutter test --update-goldens --tags golden`, uploads the `golden-baselines` artifact.
  This is the sole authoring path.
- `golden-a11y-checks` (**Golden & A11y Checks**): `runs-on: ubuntu-latest`,
  `flutter-version: 3.44.3`, `if: … && github.event_name != 'workflow_dispatch'` (the #141 fix
  — compare skips on dispatch), runs the **compare-only** boolean-OR selector
  `--tags "golden || a11y-contrast || a11y-dynamic-type"`; CI never passes `--update-goldens`.
- `flutter-checks` runs `flutter test --coverage --exclude-tags golden`.
- `a11y-checks` (**Accessibility Gate (WCAG AA)**): `runs-on: ubuntu-latest`, runs
  `--tags "a11y-contrast || a11y-dynamic-type"` on `pull_request`.

Both golden jobs run on **ubuntu-latest at the same pinned Flutter 3.44.3**, so baselines the
refresh job authors are byte-comparable to what the compare job checks. **No macOS bytes crept
in this session** — every local `--update-goldens` run (the rupee inspection and the dc07/08/09
guard verification) was discarded; `git status test/golden/goldens/` is clean. Provenance of
every committed baseline is the ubuntu refresh job.

(Required-checks / branch-protection verification for these jobs is carried into Phase 4 §4.4.)

---

## 2.4 Coverage and pyramid for the visual layer

Spot-checked three reskinned screens for widget-test depth beyond goldens:

- **Settlement history** (`settlement_history_screen_test.dart`): states (loading/empty/
  populated/error), signed-amount hues, AC-11/12 semantics, AC-13/14 telemetry, AC-15 PII
  guard — not golden-only.
- **Friend history** (`friend_history_screen_test.dart`): month-grouping, signed amounts,
  Invariant-1 sign rule, outgoing-settlement copy, error+Retry — not golden-only.
- **Activity feed** (`activity_feed_screen_test.dart` + `activity_haldi_reskin_test.dart`):
  telemetry PII hashing, deep-link tap, 2.0× no-truncate — not golden-only.

The tier is proportionate: a wide unit/widget base with goldens pinning the *look* and the
a11y families pinning contrast/dynamic-type — goldens do not substitute for behaviour tests.
The `flutter-checks` job gates aggregate coverage at ≥50% (`test-strategy.md`); per-feature
≥70% non-UI is unchanged by a visual sprint. No reskin dropped assertions (the affected-area
run is 989 green, including the new pinned cases). **No coverage finding.**

---

## Dispositions

| Bucket | Items |
|---|---|
| **A — fix now** | The `expectGoldenState` shared guard + its wiring into dc07/dc08/dc09 (test-only; re-engages the Flutter job, not a docs-only skip). |
| — | 2.2 / 2.3 / 2.4 are PASS; no Bucket-B or Bucket-C items from Phase 2. |

**Verification:** `flutter analyze test/golden test/core/theme` — No issues found;
`--tags "a11y-contrast || a11y-dynamic-type"` green; dc07/08/09 guard run green under
`--update-goldens` with bytes discarded. The dc05/dc06/dc07/dc08/dc09 baselines still require
the Phase-1 ubuntu re-baseline (Phase 7) — the guards do not change that, they only make a
wrong-state render fail loudly first.
