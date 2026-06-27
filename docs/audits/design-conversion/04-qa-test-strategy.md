# 04 — QA Verification Strategy (Golden / Contrast / Dynamic-Type)

**Phase 7 of the Design Conversion Sprint (Sprint 3).** Author: QA Engineer.
**Status: planning only — this session creates no test file, edits no `lib/**`
file, and adds no CI job.** It defines *how the conversion is verified* so that
every later conversion PR ships with a repeatable, machine-checkable proof that a
screen now matches its "Direction A — Haldi" target without regressing layout,
accessibility, money rendering, or the four invariants.

Canonical inputs (binding):

- `README.md` — the four invariants, the 30 Haldi screens + hero list, the three
  inert "Coming soon" extension slots, the verified AA/AAA pairings.
- `02-conversion-checklist.md` — the per-screen conform/reskin/rebuild/delete/
  blocked classification and the critical-path hero set (Home 6, Friends 9,
  Add-expense 21, Settle up 23, Activity 25, Splash 1).
- `03-foundation-plan.md` — the token/type foundation, the `onPrimary`/`onError`/
  `onSecondary` ink decisions, the balance trio, and the new components. The
  foundation plan explicitly delegates *"the authoritative measured contrast
  table"* to this document (§1.3, §6).
- `design_handoff_one_by_two/README.md` — the accessibility section (WCAG 2.1 AA,
  dynamic type to 2.0x, the verified pairings, the four states per screen).
- `.github/shared/test-strategy.md` — the test pyramid and coverage thresholds
  this strategy aligns to.

> Scope discipline. This conversion is **visual/UX only**. Every check below is a
> *presentation* check; none touches a data path, provider contract, repository,
> Firestore read/write, Cloud Function, security rule, or the simplified-debts
> algorithm. The backend test matrix (Functions unit/property, rules, emulator
> integration, simplified-debts canonical) is untouched and remains the
> authoritative backend gate.

---

## 0. How this fits the existing pyramid

The conversion adds **three new check families** and **reuses** the rest of the
pyramid from `.github/shared/test-strategy.md` unchanged.

| Layer | Existing? | Role in the conversion |
|---|---|---|
| Flutter widget tests (`flutter_test` + Riverpod overrides + fakes) | yes | Host for the new golden, contrast, semantics, and dynamic-type assertions. **No `mocktail`/`mockito`/`golden_toolkit`** — the built-in `matchesGoldenFile` is sufficient. |
| **Golden / screenshot regression** | **new** | Pixel baseline per converted screen × state × theme against the Haldi target (§A). |
| **Automated contrast / a11y** | **new** | WCAG pairings, balance-signal triple, semantic-label presence (§B). |
| **Dynamic-type 2.0x + reduced-motion** | **new** | No-clip/overflow at 2.0x text scale; instant-transition fallback (§C). |
| Boundary-contract grep tests (`*_boundary_contract_test.dart`) | yes | Re-run unchanged to prove invariants 1–4 survive the reskin (§D, §F). |
| Flutter flow / integration stubs (`test/integration/**`, skipped `@Tags`) | yes | Reachability guard — must stay green / stay skipped, never regress (§D item 10). |
| Functions unit/property/rules/integration + simplified-debts canonical | yes | Out of scope here; untouched. |
| Manual smoke (Tier-1 devices) | yes | VoiceOver/TalkBack walkthrough of the six heroes at release sign-off (§B.4). |

Coverage thresholds are **unchanged and not relaxed**: every Flutter feature and
every new component ≥ 70% line coverage; overall Flutter ≥ 50% (§D item 11).
Golden bytes add little line coverage, so each new component must also ship
ordinary widget tests (including at least one negative case) to clear 70%.

---

## A. Golden / screenshot regression

### A.1 Mechanism and tooling constraint

Use Flutter's **built-in** golden mechanism from `flutter_test`:
`await expectLater(find.byType(Foo), matchesGoldenFile('goldens/foo__state__theme.png'))`,
authored/refreshed with `flutter test --update-goldens`. **Do not add
`golden_toolkit`** (or `mocktail`/`mockito`) — the repository convention forbids
it and the built-in comparator covers every need here. Widgets are pumped with
the existing harness: a `ProviderScope` with overrides + hand-written fakes, the
real `AppTheme.light` / `AppTheme.dark`, wrapped in `MaterialApp`.

### A.2 Determinism prerequisites (non-negotiable for stable goldens)

A golden is only a regression signal if it is byte-stable across runs and across
the CI host. The following are **mandatory setup**, specified once in a
suite-level `test/flutter_test_config.dart` (auto-discovered by `flutter test`):

1. **Fonts must be real and local.** Haldi renders in Bricolage Grotesque +
   Hanken Grotesk via `google_fonts`. `google_fonts` fetches at runtime by
   default, which is non-deterministic and fails offline in CI. The harness must
   set `GoogleFonts.config.allowRuntimeFetching = false` and load the two
   families' `.ttf` through a `FontLoader` (from bundled font assets). Without
   this, goldens render the fallback face and are meaningless. *(The app-side
   decision to bundle the `.ttf` vs. fetch at runtime is Flutter Dev's per
   `03-foundation-plan` §3.1; golden determinism makes a locally-available font
   a hard test requirement either way.)*
2. **One host platform.** Golden bytes differ across macOS vs. Linux (font
   hinting / rasteriser). Baselines are **generated and compared on
   `ubuntu-latest`**, matching CI. Authors regenerate via the manual
   "golden refresh" path (§E), not from a local macOS `--update-goldens` run,
   whose pixels CI will reject.
3. **Pinned engine.** Flutter is pinned to 3.44.2 via FVM, so the rasteriser is
   fixed; do not float the channel for golden jobs.
4. **Pinned surface size + density.** Each golden pins
   `tester.view.physicalSize` and `devicePixelRatio` to the Haldi reference frame
   (390 × 844 logical, dpr 3.0; a second pass at the 320-wide stress width for
   dense rows — see §C). Reset in `addTearDown`.
5. **Frozen animation.** Shimmer skeletons and entrance staggers are animated;
   pump to a **fixed** frame (e.g. `tester.pump(Duration.zero)` with the shimmer
   gradient at a pinned stop) or render under reduced-motion (§C.3) so the
   loading-skeleton golden is stable.
6. **Exact comparator by default.** Keep the default exact-byte comparator; we
   *want* to catch a one-token chromatic drift. Introduce a small per-file pixel
   tolerance **only** if a shadow edge proves genuinely flaky, and record why.

### A.3 Where baselines live, how they are captured and stored

- Baselines are committed PNGs under `test/**/goldens/`, co-located with the
  widget test that renders them (e.g.
  `test/features/home/goldens/home_dashboard__populated__light.png`).
- Naming: `<screen-or-component>__<state>__<theme>.png`, states drawn from
  `{populated, empty, loading, error}` (plus screen-specific sub-states such as
  `step2-valid`, `step2-invalid`, `success`), themes `{light, dark}`.
- They are versioned in Git as the source of truth. Git LFS is optional and only
  if the PNG volume becomes a repository-size problem; not required at the start.
- Capture/refresh is a deliberate, reviewed act: run the manual golden-refresh
  path (§E) on Linux, inspect every changed PNG in the PR's "Files changed"
  image diff, and only then commit. A golden change with no corresponding,
  explained token/type/layout change is a review red flag.

### A.4 What a conversion PR must prove (non-regression)

For every screen the PR marks "converted":

1. The **new** Haldi baseline(s) are added/updated and visible in the PR diff.
2. The golden job (§E) **passes** in CI against those committed baselines on the
   canonical host — i.e. the screen renders pixel-identically to the agreed
   target on every subsequent run.
3. Any baseline that *changed* is accompanied by the token/type/layout change
   that caused it; the reviewer confirms the visual diff is the *intended* Haldi
   delta and nothing else moved.
4. The screen's pre-existing **behavioural/structural** widget tests still pass
   (or are intentionally updated in lockstep — see §A.5 and §D item 12). A golden
   alone never replaces an assertion about structure, semantics, or money.

### A.5 Golden scope differs for reskin vs. rebuild

| Class | What changes | Golden scope | Behavioural tests |
|---|---|---|---|
| **conform** (3 files) | nothing visual | none required | none new |
| **reskin** (45 files) | tokens + type only; **no layout/structure change** | Re-baseline the *same* widget tree to the Haldi skin. The diff must be purely chromatic/typographic. Keep the existing structural assertions (child count, finders, layout) **unchanged** to prove no structure moved while the golden proves the new skin. | Existing tests stay; update only the few that asserted an old token literal (e.g. the OBT widgets — §D item 12). |
| **rebuild** (4 files: Splash 1, Match-and-invite 10, Add-expense step 2, Settle up 23) | genuine layout/structure change, new control, or new state | **Fresh** baselines for the new tree; not a 1:1 re-skin. Must add goldens for the **new states** the rebuild introduces (segmented split "adds up" green / over-under red, settle-up success-moment, the styled rate-limited/self-add/duplicate guard states, the dark splash brand moment). | **New behavioural widget tests required** for the new control: e.g. segmented split-method live validation (valid → Next enabled/green; invalid → Next disabled/red), success-moment fires once with haptic, guard states render the correct copy. |
| **delete** (3 files) | removed | none | remove their tests; confirm no inbound references break |
| **blocked** (1: change-phone, FR-PR-02) | deferred — no Haldi design yet | **no golden** until the design lands | carry as a tracked follow-up; do not convert |

### A.6 Hero light + dark; four states; the non-hero rule

- **Hero screens** (Splash 1, Home 6, Friends 9, Add-expense 21, Settle up 23,
  Activity 25) ship goldens in **both light and dark**, for **every state the
  screen supports** (see the matrix in Appendix 1). Group detail 16 is a hero but
  is **built fresh in Sprint 4**, so it is out of scope here.
- **Non-hero converted screens** ship **light** goldens for every state they
  support. A **dark** golden is additionally **required** for any non-hero screen
  that renders a balance signal or a marigold/danger fill (Friend detail 11,
  Expense detail 22, Settlement history 24, Profile 27, Notification prefs 28,
  the context picker 8), because those are exactly where an `onPrimary`/`onError`
  ink regression (white-on-marigold, white-on-salmon) would hide. Elsewhere a
  dark golden is optional.
- Loading state is the **shimmer skeleton**, not a spinner (handoff mandate); the
  golden is captured at a pinned shimmer frame (§A.2.5). Empty state is the
  empty-state scaffold + flat illustration, not a bare `Icon`.

---

## B. Automated contrast / accessibility checks

### B.1 The authoritative measured-contrast table

This is the table the foundation plan delegates to QA. The first block is
**handoff-verified** (reproduced from `design_handoff_one_by_two/README.md` and
restated in `02`/`03`); these are the canonical reference figures. The second
block is **foundation design-intent** (`03-foundation-plan` §1.2–§1.3): PR #1
must record the measured value in the same test and the gate enforces the WCAG
threshold for the role.

Handoff-verified pairings. The **Handoff** column is the canonical published
figure (`design_handoff_one_by_two/README.md`, restated in `02`/`03`). The
**Measured** column is the ratio the gate actually computes from the **resolved**
`AppTheme` tokens via `Color.computeLuminance()` (see the reconciliation note
below). The gate asserts (a) the WCAG **role threshold** as a hard pass/fail and
(b) a **±0.1 drift tripwire around the Measured figure**, so a one-token chromatic
regression is caught. Every pairing clears its role threshold by both figures:

| Pairing (foreground on background) | FG | BG | Handoff | Measured | WCAG | Role |
|---|---|---|---|---|---|---|
| Ink on background (light) | `#2A211B` | `#FBF6EE` | 13.9:1 | **14.66:1** | AAA | Body text / amounts on canvas |
| Ink on marigold (`onPrimary`) | `#2A211B` | `#E0922E` | 5.6:1 | **6.25:1** | AA | Primary button + FAB label/glyph |
| Positive on white | `#0F7D6B` | `#FFFFFF` | 4.6:1 | **5.04:1** | AA (body) | "you are owed" balance text |
| Negative on white | `#BC4030` | `#FFFFFF` | 5.1:1 | **5.36:1** | AA (body) | "you owe" / destructive text |
| Dark text on dark canvas | `#F3EBDD` | `#1A1510` | 14.2:1 | **15.31:1** | AAA | Body text / amounts on canvas (dark) |

> **Reconciliation (DC-12).** The Measured figures are what
> `test/app/theme_contrast_test.dart` asserts (`closeTo`, ±0.1). They run ~0.3–1.1
> higher than the Handoff figures because the gate reads the *resolved* theme
> tokens and uses Flutter's sRGB `Color.computeLuminance()`, whose rounding differs
> from the handoff's published method. The published figures remain the canonical
> design reference; the gate tracks the resolved-token reality. Both clear the
> AA/AAA role thresholds, so the conversion is verified either way — there is **no
> token change** (any token tuning routes to issue #128).

Foundation design-intent (gate = meets role threshold; the **Measured** column is
the value `theme_contrast_test.dart` records via `Color.computeLuminance()`):

| Pairing | FG | BG | Intent | Measured | Role |
|---|---|---|---|---|---|
| `onPrimary` dark — ink on marigold-dark | `#1A1510` | `#EAA24A` | ≥ 4.5 (AA) | **8.43:1** | Primary affordance (dark) |
| `onError` dark — ink on danger-dark salmon | `#1A1510` | `#F2856B` | ≈ 7.2 | **7.20:1** | Destructive label (dark) |
| `onSecondary` light — cream on terracotta | `#FFF7E8` | `#C75D3C` | ≥ 3.0 (large/UI) | **3.90:1** | Accent icon / short label |
| `onTertiary` light — white on success | `#FFFFFF` | `#0F7D6B` | 4.6 (AA) | **5.04:1** | Success label (light) |
| `onTertiary` dark — ink on success-dark | `#1A1510` | `#34C0A4` | ≥ 3.0 (large/UI) | **7.96:1** | Success label (dark) |

**Canonical negative case (must be asserted to FAIL-as-rejected):** white on
marigold, `#FFFFFF` on `#E0922E` ≈ **2.5:1**. The gate asserts `onPrimary` is the
ink token, never white — the single most common reviewer-surprise of the
conversion (`03` §1.2).

### B.2 The contrast gate

A pure-Dart widget/unit test (no extra dependency) that:

- Reads the **resolved** token pairs from `AppTheme.light` / `.dark`
  `ColorScheme` and the `OBTColors` extension (not hard-coded hex in the test —
  read what the theme actually produces, so the gate catches a theme typo).
- Computes the WCAG 2.1 contrast ratio `(L1 + 0.05) / (L2 + 0.05)` using the
  standard sRGB relative-luminance formula.
- **Given** the Haldi theme is active, **When** each pairing in §B.1 is measured,
  **Then** the ratio meets its role threshold (≥ 4.5:1 body text, ≥ 3:1
  large/UI/non-text), and for the verified block is within ±0.1 of the
  **Measured** figure recorded in §B.1 — the resolved-token ratio the gate
  computes, not the published handoff figure (Flutter's luminance method renders
  it ~0.3–1.1 higher; see the §B.1 reconciliation note).
- **Negative case:** asserts the white-on-marigold pairing is **not** emitted by
  any primary affordance (i.e. `colorScheme.onPrimary` is the ink token), and
  fails if `onPrimary`, `onError` (dark), or `onTertiary` ever resolve to a
  foreground that drops below threshold against their fill.

This gate lives once, against the theme, and is the load-bearing guard for PR #1;
per-screen contrast is then inherited because every screen consumes the same
`ColorScheme`/`OBTColors` (no per-screen hex).

### B.3 Balance signal = colour + icon + label (never colour alone)

Invariant-grade accessibility rule (`README`, `03` §1.5). For every balance
surface (Home net header + top-balance tiles, Friends rows, Friend-detail header,
the shared `OBTBalancePill`, Settle-up header) a widget test asserts the **triple**:

| Branch | Colour token | Icon (rounded) | Label copy |
|---|---|---|---|
| Positive (owed) | success / `balancePositive` | `arrow_upward` | "owes you" / "you are owed" |
| Negative (owe) | danger / `balanceNegative` | `arrow_downward` | "you owe" |
| Zero (settled) | `balanceZero` | `check` | "Settled up" |

- **Given** a positive/negative/zero balance, **When** the pill renders, **Then**
  the test independently finds the **directional icon** *and* the **text label**
  (greyscale/colour-blind survival: the assertion does not read colour to prove
  intent) *and* confirms the colour token is the correct branch.
- **Negative case:** a balance rendered with colour only — no icon, or no label —
  **fails**. This is the canonical regression a careless reskin introduces and
  must be explicitly tested on the shared `OBTBalancePill`.

### B.4 Every control is labelled

- Automated layer: a reusable helper `expectAllInteractiveNodesLabelled(tester)`
  walks the rendered `SemanticsNode` tree and asserts every node carrying a tap /
  toggle / button action has a non-empty `label`. Applied to each converted
  screen's populated golden state. The existing OBT suites already assert
  semantics labels (FAB "Add new expense", bottom-nav items, confirmation
  dialog); this generalises that discipline to **every** converted control,
  including the new components (segmented split control, balance pill, category
  chip, skeleton-loader's accessibility-hidden decorations, the inert
  "Coming soon" slots which must be labelled and announced as disabled).
- Manual layer (release sign-off, per the test pyramid + handoff): a VoiceOver
  (iOS) and TalkBack (Android) walkthrough of the six heroes on the **Tier-1**
  device matrix, confirming reading order, the balance triple is announced as
  text (not colour), and disabled "Coming soon" slots announce their disabled
  state.

---

## C. Dynamic type to 2.0x (and reduced motion)

### C.1 The 2.0x overflow/clip gate

The handoff requires **dynamic type to 2.0x without clipping**. A widget test
wraps each hero and each dense row in
`MediaQuery(data: MediaQueryData(textScaler: TextScaler.linear(2.0)), child: …)`
(Flutter 3.44 uses `TextScaler`, not the deprecated `textScaleFactor`) and:

- **Given** 2.0x text scale, **When** the screen/row lays out, **Then**
  `tester.takeException()` is null and no `RenderFlex overflowed` /
  overflow error is logged (the yellow-black stripe never appears).
- Key elements remain fully visible (their paint rect is contained within the
  viewport; `ensureVisible` succeeds for scrollable content).
- The stress matrix is **2.0x × narrow width**: run at the 390-wide reference
  frame *and* a 320-wide frame (worst-case narrow Tier-1 device), because overflow
  is worst at narrow width × large scale.

### C.2 Dense rows that must survive 2.0x

Every amount-bearing or pill/chip-bearing row, because these are where 2.0x
breaks first:

- Net-balance hero amount (Home 6) and the Bricolage tabular amount styles.
- `OBTBalancePill` (Home/Friends/Friend-detail) — colour + icon + label must all
  stay on-row, not wrap into clipping.
- Category chip / tile (Add-expense step 1, Home legend) — icon + label.
- Top-balance tile, friend-list tile, `OBTActivityRow`, split row, settle-up
  header amount, settlement-history sent/received row, `OBTAmountInput`.
- **Amounts never truncate.** A specific assertion: amount text is **never**
  ellipsised or clipped at 2.0x — a truncated rupee figure is a defect, not a
  graceful degradation. Amounts may wrap or the row may grow; the digits must
  remain whole.

### C.3 Reduced motion

`03` §2.3 marks reduced-motion *"an accessibility requirement, not a nicety."* A
test pumps each animated surface under
`MediaQuery(data: MediaQueryData(disableAnimations: true), …)` (and/or
`accessibleNavigation: true`) and asserts transitions collapse to instant
cross-fades: skeleton→content is immediate, page push/pop and the FAB press-spring
do not animate, and no animation controller is left running. This is also the
clean way to capture a deterministic loading-skeleton golden (§A.2.5).

---

## D. Per-screen "converted" acceptance gate

A screen may be marked **converted** in its PR **only when every box is ticked**.
This *is* the Sprint 3 per-screen Definition of Done; a PR that closes a
conversion issue without all boxes is incomplete and must be returned to the
developer.

1. **Tokens + type swapped.** No raw Haldi hex at call sites — all colour via
   `ColorScheme` / `OBTColors`; all type via `TextTheme` / the `OBTText` amount
   helper. (Guardable by grep: no `Color(0xFF…)` Haldi literal outside
   `theme.dart`; no literal `fontSize:` / `GoogleFonts.<family>()` at a screen
   call site.)
2. **All four states present** — populated, empty, **loading = shimmer skeleton**
   (not a spinner/`CircularProgressIndicator`), error (Retry + Contact support).
   Empty state uses the empty-state scaffold + illustration.
3. **Light + dark for heroes** (and for the balance/marigold non-heroes in §A.6).
4. **Golden baseline(s) added/updated** for each required state × theme, and the
   PR's image diff shows the intended Haldi delta only (§A.4).
5. **Contrast gate passes** (§B.1–§B.2), including the white-on-marigold negative
   case.
6. **Balance signal is colour + icon + label** on every balance surface (§B.3),
   with the colour-only negative case proven to fail.
7. **Every control is labelled** (§B.4 automated layer green).
8. **Dynamic type 2.0x** — no clip/overflow on the screen and its dense rows;
   amounts never truncate (§C). Reduced-motion fallback verified where animated.
9. **Invariant 1 — integer paise.** The screen's `*_boundary_contract_test.dart`
   stays green; rupee strings come **only** from `formatInrFromPaise()`; no
   `paise / 100` arithmetic is introduced; `OBTAmountInput`'s `onChanged(int
   paise)` contract is untouched.
10. **Invariant 2 — `simplifiedBalances` read-only in the UI.** The balance pill,
    settle-up sheet, and any balance surface **read** the server projection only;
    no widget writes it. The settle-up flow still renders **one** pre-filled
    suggested payment, never a who-paid-whom graph.
11. **Reachability preserved (critical-journey check).** The converted screen is
    still reachable from a navigation entry point — no orphaned screen, no
    never-overridden provider — and the executable flow/widget journey that
    exercises it (e.g. `authenticated_shell_fab_integration_test.dart`,
    `add_friend_flow_e2e_test.dart`) still passes. The skipped
    `test/integration/**` emulator stubs stay skipped, never silently deleted.
12. **Coverage not regressed.** Per-feature and per-new-component ≥ 70%; overall
    Flutter ≥ 50%. Each new component ships its own widget tests with **at least
    one negative case**.
13. **Contract tests updated in lockstep where a token contract legitimately
    changed** — e.g. the six OBT widgets: the FAB test currently asserts
    `backgroundColor == secondary` and `foregroundColor == Colors.white`; under
    Haldi these become `primary` (marigold) and `onPrimary` (ink). The assertion
    change must be **intentional, reviewed, and traceable to `03` §1.2/§4.1**, not
    an accidental break papered over by `--update-goldens`.
14. **Invariants 3 + 4 untouched** — share path still the OS system share sheet;
    no second Firebase project introduced.
15. **Milestone hygiene.** The closing issue carries the **Sprint 3** milestone
    per `.github/shared/milestone-tracking.md`; a closed conversion issue with no
    milestone is a tracking defect.

**Sprint 3 Definition of Done (roll-up).** Sprint 3 is done when: every in-scope
screen in `02-conversion-checklist.md` is "converted" per the gate above; the
three deletes are removed; the one blocked screen (change-phone, FR-PR-02) is a
tracked follow-up, not silently dropped; the golden + contrast + dynamic-type CI
job (§E) is green and required on `main`; coverage holds; and the four
boundary-contract invariant suites are green.

---

## E. CI — the accessibility gate (wired) and the golden job (specified)

### E.1 The accessibility gate — `a11y-checks` (DC-12, wired in `pr.yml`)

DC-12 (#124) wires the contrast + dynamic-type families as a **named, blocking CI
gate** so a reviewer sees them pass/fail by name and the conversion can never
silently regress on a future PR. This is **separate** from the golden job below
(DC-13): it runs for real on every host and needs no committed baselines.

- **Job key / name:** `a11y-checks` / "Accessibility Gate (WCAG AA)".
- **Trigger / gating:** rides `pr.yml`; `needs: [changes]`; runs when
  `needs.changes.outputs.flutter == 'true'` or `…ci == 'true'`, with the same
  `needs.changes.result != 'success'` fail-safe (a skipped run reports "skipped",
  which the ruleset counts as passing).
- **Runner / setup:** `ubuntu-latest`; `actions/checkout@v4`;
  `subosito/flutter-action@v2` (`channel: stable`, `cache: true`); `flutter pub
  get`. **No Firebase, no emulator, no secrets** (Invariant 4 trivially holds).
- **What it runs:**
  `flutter test --tags "a11y-contrast || a11y-dynamic-type"` — the boolean **OR
  selector** runs BOTH families (the §B contrast pairings, incl. the
  white-on-marigold and DC-11 white-on-warm-fill-dark negative cases, and the §C
  2.0x overflow/clip + reduced-motion gate). **The repeated form
  `--tags a --tags b` is _last-wins_** and silently runs only the last family
  (verified: it ran 6 of the 26 tagged tests), so the `||` selector is mandatory —
  the same form the golden job below must use for its multi-tag selection.
- **Failure semantics:** any contrast pairing below its role threshold (or a
  negative case passing), any 2.0x overflow/clip, or any reduced-motion regression
  fails the job. These tests also run inside the `flutter-checks` full
  `flutter test --coverage`; this job re-runs the tagged subset only to surface it
  as a *named* check. To make it merge-blocking, the `avtansh-code` owner adds
  "Accessibility Gate (WCAG AA)" to the branch ruleset's required checks.
- **Coverage:** unchanged — `coverage-gate` (SRS 5.7) remains the single coverage
  authority; this job adds no coverage step.

### E.2 The golden job — `golden-a11y-checks` (DC-13, wired in `pr.yml`)

**DC-13 (#125) wires this job** in `.github/workflows/pr.yml` and commits the
baselines. It is **separate** from the DC-12 `a11y-checks` gate above: the
golden job **pins the Flutter version** because golden bytes are
engine-sensitive, whereas `a11y-checks` floats the stable channel and runs no
byte comparison.

- **Job key / name:** `golden-a11y-checks` / "Golden & A11y Checks".
- **Trigger:** rides the existing `pull_request → main` (and `workflow_dispatch`)
  triggers of `pr.yml`. Gated via the existing `changes` detection:
  runs when `needs.changes.outputs.flutter == 'true'` or `…ci == 'true'`, with
  the same fail-safe (`needs.changes.result != 'success'` → run anyway). A
  skipped run reports "skipped", which the ruleset counts as passing.
- **Runner / setup:** `ubuntu-latest` (the canonical golden host — see §A.2.2);
  `actions/checkout@v4`; `subosito/flutter-action@v2` **pinned to
  `flutter-version: 3.44.3`** (not just `channel: stable`, §A.2.3 — do not float
  the channel for golden jobs) with `cache: true`. **No Firebase, no emulator,
  no secrets** — these are pure `flutter test` runs.
- **Determinism:** the harness (`golden_harness.dart` +
  `test/golden/flutter_test_config.dart`) bundles the Bricolage Grotesque +
  Hanken Grotesk OFL `.ttf` under `test/golden/fonts/` and serves them to
  `google_fonts` through its `@visibleForTesting` http seam, so the real Haldi
  type ramp rasterises identically offline; rendering runs under reduced motion
  at the pinned 390 × 844 @ dpr 3 frame (§A.2). `flutter-checks` now runs the
  full suite with `--exclude-tags golden`, so byte-exact goldens compare **only**
  on this pinned job, while the `a11y-contrast` / `a11y-dynamic-type` families
  still run in `flutter-checks` and keep contributing coverage.
- **What it runs:** `flutter pub get`, then the tagged check suites via the boolean
  OR selector — `flutter test --tags "golden || a11y-contrast || a11y-dynamic-type"`
  (golden comparison + contrast + semantics/dynamic-type). Use the `||` selector,
  **not** repeated `--tags` (last-wins; see §E.1). It runs **comparison only**;
  CI never passes `--update-goldens` (that would make every run trivially pass).
- **Where goldens live:** committed under `test/golden/goldens/**`, as in §A.3.
  CI compares the running render against those committed baselines on the fixed
  host.
- **Failure semantics (required check, blocks merge):** any golden mismatch,
  any contrast pairing below threshold (or the white-on-marigold negative case
  appearing), any 2.0x overflow/clip, or any unlabelled interactive control fails
  the job. On a **golden** failure it uploads Flutter's generated
  `failures/*_testImage.png`, `*_masterImage.png`, `*_isolatedDiff.png`,
  `*_maskedDiff.png` via `actions/upload-artifact@v4` so reviewers can see the
  pixel diff without re-running locally. The `avtansh-code` owner adds "Golden &
  A11y Checks" to the branch ruleset's required checks to make it merge-blocking.
- **AC-3 (the negative case is real, in two halves):** a chromatic/typographic
  regression (e.g. reintroducing Indigo `#1F4E79`, or a font swap) lands as a
  **pixel diff** that fails this job; a white-on-marigold / white-on-warm-fill
  `on*`-ink regression is caught by the `a11y-contrast` pairing gate
  (`theme_contrast_test.dart` asserts the white-on-marigold negative case
  directly). Both halves block merge.
- **Baseline refresh path:** the `workflow_dispatch`-only **`golden-refresh`**
  job runs `flutter test --update-goldens --tags golden` on the **same pinned
  ubuntu image** and uploads the regenerated PNGs as the `golden-baselines`
  artifact for a developer to review and commit — so baselines are always
  authored on the host CI compares against, never on a local macOS machine, and
  a PR never runs a silent `--update-goldens` (AC-2).
- **Invariant 4 / secrets:** the job introduces **no** Firebase project and makes
  no `firebase` CLI call (so the `block-second-firebase-project` guard is
  trivially satisfied); it references no secrets. It is idempotent and safe to
  re-run.
- **Coverage:** these widget tests' coverage is owned by the `coverage-gate`
  (SRS 5.7); the golden job adds no coverage step.

The wired jobs (`.github/workflows/pr.yml`) — the compare gate plus the
manual-only refresh path:

```yaml
  golden-a11y-checks:
    name: Golden & A11y Checks
    runs-on: ubuntu-latest
    needs: [changes]
    if: >-
      !cancelled()
      && (needs.changes.result != 'success'
      || needs.changes.outputs.flutter == 'true'
      || needs.changes.outputs.ci == 'true')
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: 3.44.3 # pinned: golden bytes are engine-sensitive
          channel: stable
          cache: true
      - name: Install dependencies
        run: flutter pub get
      - name: Golden + contrast + dynamic-type checks (compare only)
        run: flutter test --tags "golden || a11y-contrast || a11y-dynamic-type"
      - name: Upload golden failure diffs
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: golden-failures
          path: '**/failures/*.png'
          retention-days: 14
          if-no-files-found: ignore

  golden-refresh: # manual baseline authoring — workflow_dispatch only
    name: Golden Refresh (manual)
    runs-on: ubuntu-latest
    if: github.event_name == 'workflow_dispatch'
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: 3.44.3
          channel: stable
          cache: true
      - name: Install dependencies
        run: flutter pub get
      - name: Regenerate golden baselines (ubuntu-latest)
        run: flutter test --update-goldens --tags golden
      - name: Upload regenerated baselines for review
        uses: actions/upload-artifact@v4
        with:
          name: golden-baselines
          path: test/golden/goldens/**
          retention-days: 14
```

---

## F. The four invariants — untouched and re-affirmed

This is a **visual/UX-only** sprint; the Haldi handoff restates each invariant and
weakens none. The verification strategy actively *guards* all four:

1. **Money is integer paise.** Rupee strings come only from
   `formatInrFromPaise()`; the boundary-contract suites and §D item 9 keep the
   reskin from introducing `paise / 100`.
2. **`simplifiedBalances` is server-written / client-read-only.** No new or
   reskinned widget writes the field; the balance pill and settle-up components
   read the projection only; settle-up still shows one pre-filled suggested
   payment (§D item 10). Server writers — `recomputeSimplifiedBalances`,
   `onExpenseWriteFriendship`, `onSettlementWrite` — are unchanged.
3. **OS system share sheet only.** Invite affordances keep delegating to
   `share_service.dart`; no platform-specific share target is imported by any new
   component (§D item 14).
4. **Single Firebase project.** The golden/a11y job runs no Firebase and adds no
   project; the `.firebaserc` single-project guard and the Emulator Suite are
   untouched (§E).

The three inert extension slots — Settle Up → "Pay via UPI", Add Expense step 3 →
"Make recurring", Profile → Notifications → "Language" — ship **present but
disabled** and labelled "Coming soon"; the acceptance gate's semantics check
(§B.4) and golden states (§A) verify they render and announce as disabled, and a
behavioural test verifies they are **not wired**. Building any of them live would
be a blocking defect.

---

## G. Hand-offs and ownership

- **QA → Flutter Dev:** this strategy is the per-PR review rubric (§D). Review
  feedback that cites a missing golden state, a failed pairing, a 2.0x clip, an
  unlabelled control, or a colour-only balance is a correctness block, not a nit.
- **QA → DevOps:** the §E job specification is the input to the
  `add-github-actions-job` skill (a separate Sprint 3 task). DevOps owns the
  workflow edit; QA owns the spec and signs off the resulting required check.
- **QA → Architect:** any contrast pairing that cannot meet its threshold with
  the planned tokens, or any ambiguity in an `on*` ink decision, routes to the
  Architect (ADR-0024 / `03` §1.2–§1.3) — not resolved by relaxing the gate.
- **Coverage / pyramid authority:** `.github/shared/test-strategy.md` is
  unchanged; this document adds check families and tightens the per-screen DoD,
  it does not move a threshold.

---

## Appendix 1 — Hero golden state matrix (in-scope this sprint)

| Haldi № | Hero | Class | Golden states (each in **light + dark**) |
|---|---|---|---|
| 1 | Splash | rebuild | brand moment (single state) |
| 6 | Home dashboard | reskin | populated, empty (new-user), loading-skeleton, error |
| 9 | Friends list | reskin | populated, empty, loading-skeleton, error |
| 21 | Add-expense (3-step sheet) | reskin + steps 2/3 rebuild | step1, step2-valid (green), step2-invalid (red, Next disabled), step3 (incl. inert "Make recurring") |
| 23 | Settle up | rebuild | populated (pre-filled, incl. inert "Pay via UPI"), success-moment, error |
| 25 | Activity feed | reskin | populated, empty, loading-skeleton, error |

> Group detail (Haldi 16, hero) is **built fresh in Sprint 4**, not converted
> here; its golden matrix is authored with that build.

## Appendix 2 — Test tags

- `golden` — golden comparison tests.
- `a11y-contrast` — WCAG pairing tests (§B.1–§B.2).
- `a11y-dynamic-type` — 2.0x overflow/clip + semantics-label + reduced-motion
  tests (§B.4, §C).

These tags let the §E jobs select the new families without disturbing the existing
`flutter test` run, and let `flutter test --exclude-tags golden` stay fast for
developers who are not touching visuals.

To select **more than one** tag family in a single run, use the boolean OR
selector — `flutter test --tags "a11y-contrast || a11y-dynamic-type"`. Repeated
`--tags a --tags b` is **last-wins** and silently runs only the last family, so it
must not be used for a multi-family gate (this is how the DC-12 `a11y-checks` job
and the DC-13 golden job select their families — §E.1).
