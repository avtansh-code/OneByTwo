# Phase 1 — Design-Fidelity Validation (the headline)

**Owner:** Designer (lead) + Flutter Dev (implements) + Architect (contract rulings) +
QA (re-baselines + sign-off)
**Method:** `docs/copilot_prompts/sprint_3/retro-design-validation.md`, run against the
authoritative handoff `design_handoff_one_by_two/` (Phase2 components, Phase3a/b/c/e/f/g
screens). Groups (Phase3d) and Marketing (Phase4) are out of scope.
**Status:** Findings remediated in the cleanup PR. Goldens re-baseline on `ubuntu-latest`
at PR time (Phase 7) — not on macOS.

---

## 1. Approach — the fidelity matrix

Every amount-rendering shared component (Phase2) and every converted screen + state
(Phase3a/b/c/e/f/g) was checked side-by-side against its handoff reference across:
colour token, type family/size/weight, radius, shadow/outline, spacing, icon,
**one-line-vs-wrap**, and the four states (loading / empty / populated / error) in light +
dark. Two load-bearing dimensions — carried in from the validation prompt as known inputs —
are the headline and are recorded exhaustively below: **(A) the single-line-fit standard**
and **(B) the rupee-glyph (₹-in-Hanken) rule**. All other dimensions were spot-checked and
recorded PASS unless listed as a finding.

The font foundation that drives finding (B), established from `lib/app/theme.dart`:

| Family | textTheme slots | Carries ₹ (U+20B9)? |
|---|---|---|
| **Bricolage Grotesque** (display/amount) | `displayLarge`, `displayMedium`, `headlineLarge`, `headlineMedium`, **`titleSmall`** | **Yes — safe for money** |
| **Hanken Grotesk** (text/UI) | `titleLarge`, `titleMedium`, `bodyLarge`, `bodyMedium`, `bodySmall`, `labelLarge`, `labelMedium`, `labelSmall` | **No — renders ₹ as tofu** |

`OBTText.amount` / `amountPill` / `amountFocal` / `amountHero` all resolve to Bricolage
tabular and are safe. Verified by a throwaway inspection golden (discarded): the same amount
rendered in `bodyMedium` shows "You paid Riya **□**450.00" (tofu) versus, with the fix,
"You paid Riya **₹**450.00".

---

## 2. Finding B — the rupee-glyph (₹-in-Hanken) sweep

Every `formatInrFromPaise(...)` render site in `lib/**` (79 occurrences across 31 files) was
classified by the actual resolved style. **Semantics-only** strings (screen-reader labels)
and **non-render** uses (draft/validation strings in domain/application code) are not visual
defects. Result: **7 visible money renders across 4 files resolved to a Hanken slot (tofu);
all are fixed.** Every other visible amount already resolved to an `OBTText.amount*` Bricolage
helper (PASS).

### Findings (fixed)

| Location | Divergence | Severity | Action | Owner |
|---|---|---|---|---|
| `features/expenses/.../steps/step_2_split_and_payer.dart:165` | "Total" amount on `titleMedium` (Hanken) | High | **Fix now** — swap to `OBTText.amount` | Flutter Dev |
| `core/widgets/sheets/obt_settle_up_sheet.dart:246` | success sentence "You paid … ₹…" on `bodyMedium` | High | **Fix now** — `OBTText.rupeeAware` fallback | Flutter Dev |
| `core/widgets/inputs/obt_segmented_split_control.dart:178` | "Over by ₹…" / "Short by ₹…" on `bodyMedium` | High | **Fix now** — `OBTText.rupeeAware` fallback | Flutter Dev |
| `features/friends/.../friend_history_screen.dart:277` | subtitle "you lent/borrowed ₹…" on `bodySmall` | High | **Fix now** — `OBTText.rupeeAware` fallback | Flutter Dev |

(#143 already fixed the Friends-summary band; `expense_detail_screen.dart`,
`settlement_history_screen.dart`, both spending-donut files, the balance pill, the
net-balance hero and the settle-up sheet hero already resolved to `OBTText.amount*` and are
PASS.)

### Coverage table (visible money renders + representative non-renders)

| File:Line | Style | Family | Verdict |
|---|---|---|---|
| `step_2_split_and_payer.dart:165` | `titleMedium` → `OBTText.amount` | Hanken → Bricolage | **FIXED** |
| `obt_settle_up_sheet.dart:246` | `bodyMedium` → `rupeeAware(bodyMedium)` | Hanken → +fallback | **FIXED** |
| `obt_segmented_split_control.dart:178` | `bodyMedium` → `rupeeAware(bodyMedium)` | Hanken → +fallback | **FIXED** |
| `friend_history_screen.dart:277` | `bodySmall` → `rupeeAware(bodySmall)` | Hanken → +fallback | **FIXED** |
| `obt_segmented_split_control.dart:183` | `OBTText.amount` | Bricolage | PASS |
| `obt_settle_up_sheet.dart:301` | `OBTText.amountHero` | Bricolage | PASS |
| `obt_settle_up_card.dart:205` | `OBTText.amountFocal` | Bricolage | PASS |
| `obt_activity_row.dart:120` | `OBTText.amount` | Bricolage | PASS |
| `friend_history_screen.dart:287` | `OBTText.amount` | Bricolage | PASS |
| `friend_detail_timeline.dart:151` | `OBTText.amount` | Bricolage | PASS |
| `net_balance_header_card.dart:62/68` | `OBTText.amountHero` | Bricolage | PASS |
| `expense_detail_screen.dart:319/489` | `OBTText.amount` | Bricolage | PASS |
| `settlement_history_screen.dart:314` | `OBTText.amount` | Bricolage | PASS |
| `obt_spending_donut.dart:113/204`, `spending_donut_chart.dart:74` | `OBTText.amount` | Bricolage | PASS |
| `spending_breakdown_card.dart:285` | `OBTText.amount` | Bricolage | PASS |
| `split_row.dart:57`, `step_3_receipt_and_confirm.dart:455` | `OBTText.amount` | Bricolage | PASS |
| `friend_list_tile.dart:182`, `top_balance_tile.dart:85/214`, `spending_breakdown_card.dart:256`, `obt_activity_row.dart:203`, `settlement_history_screen.dart:261`, `obt_spending_donut.dart:180` | `Semantics(label:)` only | — | non-render |
| `add_expense_controller.dart:1042-1044`, `settle_up_draft.dart:91`, `monthly_spend_breakdown.dart`, `net_balance.dart`, `friend_list_item.dart` | domain/application string | — | non-render |

---

## 3. Finding A — the single-line-fit sweep

Every element the handoff draws on one line must render on one line and **scale its text down
to fit** (`FittedBox(scaleDown)` + `maxLines:1` + `softWrap:false`) — never wrap, and money
never truncates/ellipsises. #143 fixed the balance pill, the home top-balance row, and the
Settle-Up gap; those held. The established protected pattern (`FittedBox(scaleDown)`) was
already present on the balance pill, the net-balance hero, the friend-detail header, the
settlement-history signed amount and the segmented-split labels — but **seven standalone
amount figures rendered as a bare `Text`**, exposed to overflow-clipping at large values /
2.0× type. All are wrapped to scale-to-fit, using `Flexible` in row contexts so short amounts
stay byte-identical (only long amounts scale — low golden churn).

| Location | Divergence | Severity | Action | Owner |
|---|---|---|---|---|
| `obt_settle_up_sheet.dart:300` | hero amount (48px) bare; can overflow at narrow width | Medium | **Fix now** — `FittedBox(scaleDown)` | Flutter Dev |
| `obt_settle_up_card.dart:205` | focal amount (32px) bare | Medium | **Fix now** — `FittedBox(scaleDown)` | Flutter Dev |
| `obt_activity_row.dart:120` | trailing row amount bare | Medium | **Fix now** — `Flexible`+`FittedBox` | Flutter Dev |
| `friend_history_screen.dart:287` | trailing amount bare (twin of the protected `settlement_history`) | Medium | **Fix now** — `Flexible`+`FittedBox` | Flutter Dev |
| `friend_detail_timeline.dart:151` | trailing share amount bare | Medium | **Fix now** — `Flexible`+`FittedBox` | Flutter Dev |
| `spending_breakdown_card.dart:285` | category subtotal bare | Low | **Fix now** — `Flexible`+`FittedBox` | Flutter Dev |
| `split_row.dart:57` | per-person split amount bare | Low | **Fix now** — `FittedBox(scaleDown)` | Flutter Dev |

The existing `a11y-dynamic-type` and reskin "amount never truncates at 2.0×" gates pass
unchanged (989 affected tests green), and a new pinned widget case asserts the settle-up card
focal amount scales inside a `FittedBox` at a 300 dp width without overflow.

---

## 4. Finding D — foundation-token integrity (§4.1 / ADR-0025)

Spot-checked and confirmed shipped as ADR-0025 records:

- The three amount tiers exist and are used by emphasis: `OBTText.amount` (16px row),
  `amountFocal` (32px, settle-up card), `amountHero` (48px, net-balance + amount entry).
- Colour reserved for balance: the activity-row trailing amount is neutral `onSurface` and
  keeps success green only for `settlementRecorded`; the `₹` amount-field prefix uses
  `onSurfaceVariant`, not `primary`.
- Settle-up card separation: `BoxDecoration` with the marigold `heroShadow` in light and a
  1px `outline` border in dark (verified by its widget test).
- The token table, type ramp and radii in `lib/app/theme.dart` match the README master table.

No token, ramp, radius or shadow finding. (Tabular-figures note: `displayMedium`/`headline*`
in the raw theme lack tabular figures, but every *amount* path goes through an `OBTText.amount*`
helper that adds them — so no amount renders non-tabular. Recorded as PASS.)

---

## 5. Ratified approach (Architect + Designer ruling)

These are display-only changes; no token/component/§4.1 contract is relaxed, so no decision-log
amendment is required (the rupee rule and single-line-fit standard are *restated*, not changed,
from ADR-0024/0025 and #143). A back-port of both as written conventions is filed in Phase 3.

- **R1 — standalone amount on a Hanken slot:** swap the style to `OBTText.amount` (Bricolage
  tabular). [`step_2_split_and_payer.dart`]
- **R2 — amount embedded in a Hanken sentence:** new helper `OBTText.rupeeAware(ThemeData, TextStyle?)`
  appends the Bricolage family (read from the theme's `titleSmall` amount slot) to the run's
  `fontFamilyFallback`, so only the missing ₹ glyph borrows Bricolage while the prose stays
  Hanken — the closest match to the handoff's uniform sentence, prompt-sanctioned, DRY, and
  low-churn. [4 sentence sites]
- **R3 — single-line-fit:** wrap unprotected standalone amount figures in
  `FittedBox(fit: BoxFit.scaleDown)` with the inner `Text` `maxLines:1, softWrap:false`, using
  `Flexible` in row contexts so short amounts are unchanged. [7 sites]

---

## 6. Dispositions

| Bucket | Items |
|---|---|
| **A — fix now** | All of Findings A (7) and B (4 fixes covering 7 renders) above; the new `OBTText.rupeeAware` helper; the new pinned tests. **Done in this branch; goldens re-baseline on ubuntu at PR time.** |
| **C — accept + document** | `obt_segmented_split_control.dart:183` running allocated-total: bounded by a single expense total and sits inside a bespoke validation control that already uses `FittedBox` for its segment labels — scale-to-fit wrap deferred; magnitude cannot realistically overflow. Recorded here so it is not re-flagged. |

No Bucket-B items from Phase 1.

---

## 7. Goldens to re-baseline on ubuntu (Phase 7)

The fixes change rendered pixels, so these baseline families are expected to diff and **must be
regenerated via the `golden-refresh` `workflow_dispatch` job and reviewed as images** before
merge (never `--update-goldens` on macOS):

- `dc07_expenses_*` (step_2 Total now Bricolage; split rows scale-to-fit; segmented-split ₹).
- `dc08_settlements_*` (settle-up sheet hero + success sentence ₹; settle-up card focal scale).
- `dc06_friends_*` (friend-history descriptor ₹; friend-history + timeline amounts scale).
- `dc05_home_*` (spending-breakdown subtotal scale-to-fit, where the donut/legend is shown).
- `dc09_activity_*` (activity-row trailing amount scale-to-fit).
- `haldi_components_*` / `obt_widgets_reskin_*` (segmented split, settle-up card, activity row).

Every diff must be the intended ₹/scale delta and nothing else.

---

## 8. Verification (local, this session)

- `flutter analyze lib test` — **No issues found.**
- `dart format` — clean (0 changed).
- `flutter test --exclude-tags golden` over the affected areas (core/theme, core/widgets,
  expenses, friends, home, activity, settlements) — **989 passed.**
- New tests: `test/core/theme/obt_text_test.dart` (the `rupeeAware` contract);
  `obt_settle_up_card_test.dart` (focal scale-to-fit at 300 dp, no overflow).
- Goldens deliberately NOT regenerated locally (host-sensitive). Re-baseline + image review
  on ubuntu is a Phase-7 gate.

**Invariants:** all hold — visual/display only. `formatInrFromPaise()` stays the sole paise→INR
boundary; scaling text changes font size, not values; no `paise/100`, no `double` money math;
`simplifiedBalances` is read-only; share sheet untouched; single Firebase project untouched.
