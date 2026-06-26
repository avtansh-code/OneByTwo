# 03 — Token, Type and Component Foundation Plan (Phase 3)

**Status:** Planning (Sprint 3 preparation). **No `lib/**` file is edited in this session.**
**Authors:** Architect (this document), with Designer.
**Scope:** the shared foundation every Haldi screen depends on — the `lib/app/theme.dart`
migration to the Haldi token set, the typeface swap, the shared-widget impact, the new
components the Haldi catalogue requires, and the invariant-preservation guarantees.
**Canonical inputs:** `docs/audits/design-conversion/README.md` (framing, the four invariants,
the renumber mapping, ADR number) and `design_handoff_one_by_two/README.md` (the authoritative
Haldi visual system). The adoption decision is **ADR-0024** in `.github/shared/decision-log.md`.

> This is a plan, not code. It enumerates contracts (token names, hex values, Flutter
> `TextTheme`/`ColorScheme` slots, radii, motion). The first conversion PR — **Sprint 3 PR #1
> — design-token foundation** — implements it against `lib/app/theme.dart`. Flutter Dev writes
> the Dart; QA (`04-qa-test-strategy.md`) verifies the contrast/dynamic-type/golden gates.

---

## 0. Why this is PR #1 (sequencing)

The token-and-type foundation is the **single blocking dependency for the entire Design
Conversion Sprint.** Every screen reskin (`06` Home, `09` Friends, `16` Group detail, `21` Add
expense, `23` Settle up, `25` Activity, and the remaining 24 screens) consumes
`Theme.of(context).colorScheme`, `theme.textTheme`, the shared radii, and the new shared
widgets. Converting any screen before the theme is migrated would either hard-code Haldi hex
(token drift) or render Haldi layouts in the old Indigo/Plus-Jakarta skin (a mixed,
un-reviewable state).

Therefore the order is fixed:

1. **Sprint 3 PR #1 — design-token foundation:** `lib/app/theme.dart` → Haldi `ColorScheme`,
   the `OBTColors` theme extension for the non-Material tokens, the Bricolage/Hanken
   `TextTheme`, the radius/shape/motion tokens. Plus the six shared-widget reskins, which are
   token/type-only and ride in this PR or its immediate follow-ups.
2. **Sprint 3 PR #2…n — screen conversion:** per-screen reskins and the new components, each
   building only on the merged foundation. The per-screen rebuild/reskin classification is the
   Phase-2 `02-conversion-checklist.md`; the new-component contracts are §4 below.

Nothing in this plan changes a backend contract (§5).

---

## 1. `theme.dart` colour migration — Haldi semantic set (light + dark)

The current theme (`lib/app/theme.dart`) declares thirteen `_light*` and thirteen `_dark*`
`Color` constants and threads them into a Material-3 `ColorScheme` plus
`scaffoldBackgroundColor` and `dividerColor`. The migration is a **constant-by-constant
replacement**: each existing constant keeps its `ColorScheme`/theme slot and is re-pointed at
its Haldi hex. The table below is the complete map.

### 1.1 Direct replacements (existing constant → Haldi hex)

| Current constant (light / dark) | Current hex (light / dark) | Haldi light | Haldi dark | Slot it feeds | Note |
|---|---|---|---|---|---|
| `_lightPrimary` / `_darkPrimary` | `#1F4E79` / `#2E86AB` | **`#E0922E`** | **`#EAA24A`** | `ColorScheme.primary` | Marigold ("Haldi") brand. |
| `_lightOnPrimary` / `_darkOnPrimary` | `#FFFFFF` / `#FFFFFF` | **`#2A211B`** | **`#1A1510`** | `ColorScheme.onPrimary` | **INK, not white** — see §1.2. |
| `_lightPrimaryVariant` / `_darkPrimaryVariant` | `#2E86AB` / `#5AAFCE` | `#C77F22` | `#D08F3C` | `ColorScheme.primaryContainer` → becomes `primaryPressed` | Re-roled to the Haldi *pressed marigold*; the "tonal container" role is better served by `surfaceVariant` (next-but-one row). Pressed is applied via `WidgetStateProperty` overlays, not as a long-lived fill. |
| `_lightSecondary` / `_darkSecondary` | `#F4A261` / `#F4A261` | `#C75D3C` | `#E07A55` | `ColorScheme.secondary` | Terracotta accent. |
| `_lightOnSecondary` / `_darkOnSecondary` | `#1A1A1A` / `#1A1A1A` | `#FFF7E8` (cream) | `#1A1510` (ink) | `ColorScheme.onSecondary` | Foreground flips by theme — see §1.3. Reserve terracotta for accents/icons, not long body text. |
| `_lightSuccess` / `_darkSuccess` | `#2A9D8F` / `#3CC0AF` | `#0F7D6B` | `#34C0A4` | `ColorScheme.tertiary` (= success / balancePositive) | Drives the positive balance signal. |
| `_lightDanger` / `_darkDanger` | `#E76F51` / `#F08B72` | `#BC4030` | `#F2856B` | `ColorScheme.error` (= danger / balanceNegative) | Drives the negative balance signal + destructive. |
| `onError` (literal `Colors.white`) | `#FFFFFF` / `#FFFFFF` | `#FFFFFF` | `#1A1510` (ink) | `ColorScheme.onError` | Light danger is dark → white (≈5.4:1). Dark danger `#F2856B` is light → **ink** (white only ≈2.5:1). See §1.3. |
| `_lightSurface` / `_darkSurface` | `#FFFFFF` / `#1E1E1E` | `#FFFFFF` | `#241D16` | `ColorScheme.surface` | |
| `_lightOnSurface` / `_darkOnSurface` | `#1A1A1A` / `#E8E8E8` | `#2A211B` | `#F3EBDD` | `ColorScheme.onSurface` (= text-primary) | Ink on cream 13.9:1 (AAA); `#F3EBDD` on `#1A1510` 14.2:1. |
| `_lightSurfaceVariant` / `_darkSurfaceVariant` | `#F2F4F7` / `#2A2A2A` | `#FFF6E6` | `#2E2620` | `ColorScheme.surfaceContainerHighest` | Hero card, tonal fills, chip beds. |
| `_lightBackground` / `_darkBackground` | `#F8F9FB` / `#121212` | `#FBF6EE` | `#1A1510` | `scaffoldBackgroundColor` | App canvas. |
| `_lightOutline` / `_darkOutline` | `#C4C9D1` / `#3D3D3D` | `#E7DDCD` | `#3A322A` | `ColorScheme.outline` | Doubles as the dark-theme 1px border (see §2.2). |
| `_lightDivider` / `_darkDivider` | `#E4E7EC` / `#2F2F2F` | `#E7DDCD` | `#3A322A` | `dividerColor` | Haldi unifies *outline* and *divider* into one token. |

### 1.2 The `onPrimary` ink decision (the load-bearing call)

`onPrimary` becomes the warm ink **`#2A211B`** (light) / **`#1A1510`** (dark) — **never white.**
Rationale: white text/icons on marigold `#E0922E` measure ≈ **2.5:1**, which **fails** WCAG 2.1
AA. The Haldi ink on the same marigold measures **5.6:1 (AA)** (Haldi README, Accessibility).
Every primary affordance inherits this: the FAB glyph, primary-button labels, and any icon on a
marigold fill are ink, not white. This is the most common reviewer-surprise in the conversion,
so it is called out here, restated in ADR-0024, and gated by QA Phase 7.

### 1.3 Foreground principle: light/warm fills take ink

Haldi's palette generalises the §1.2 rule: **a light or warm fill takes an ink foreground; only
genuinely dark fills take a cream/white foreground.** This makes three `on*` slots diverge from
Material defaults and from the old theme; all three are flagged for the QA contrast gate:

- **`onPrimary`** — ink on marigold (both themes). White ≈2.5:1 ✗ → ink 5.6:1 ✓.
- **`onError`** — white on light-theme danger `#BC4030` ≈5.4:1 ✓; but on the *dark*-theme danger
  `#F2856B` (a light salmon) white is ≈2.5:1 ✗ → **ink `#1A1510`** ≈7.2:1 ✓.
- **`onSecondary`** — terracotta `#C75D3C` (light) pairs better with cream `#FFF7E8` (≈4.2:1,
  clears the ≥3:1 large/UI threshold) than with ink; the lighter dark terracotta `#E07A55`
  takes **ink `#1A1510`** (≈6.1:1). Terracotta is an accent — keep it for icons/short labels.
- **`onTertiary`** (success) follows the same rule: white on `#0F7D6B` (light, ≈4.6:1) and **ink**
  on the lighter `#34C0A4` (dark).

QA owns the authoritative measured table in `04-qa-test-strategy.md`; the values here are the
design intent the gate must confirm.

### 1.4 New tokens with no current constant (add as named tokens + `OBTColors` extension)

Material's `ColorScheme` has no slot for several Haldi tokens. The plan is a small immutable
`ThemeExtension` — **`OBTColors`** — registered on both `ThemeData.extensions`, carrying the
tokens below, plus a couple that map onto existing Material slots. (Extension shape is Flutter
Dev's to implement; the token set and hex are fixed here.)

| Haldi token | Light | Dark | Carried by |
|---|---|---|---|
| `balanceZero` | `#6F6557` | `#A99C8C` | `OBTColors.balanceZero` |
| `warning` | `#E8A33D` | `#F2B863` | `OBTColors.warning` |
| `primaryPressed` | `#C77F22` | `#D08F3C` | `OBTColors.primaryPressed` (overlay state) |
| `textSecondary` | `#6F6557` | `#B9AE9D` | `ColorScheme.onSurfaceVariant` (existing slot; already consumed by `OBTActivityRow`, `OBTSettleUpCard`) |
| `textTertiary` | `#776E64` | `#9C8E7C` | `OBTColors.textTertiary` (meta/timestamps; AA-tuned in DC-02 — the original `#9A8F82` / `#8A7E6E` measured ~2.95:1 / ~3.74:1, below WCAG 2.1 AA for 12px meta text) |
| `disabledFill` / `disabledText` | `#E4DCCE` / `#B8AC9B` | `#332B23` / `#6B6053` | `OBTColors.disabledFill` / `.disabledText` |
| `link` | `#A35E16` | `#EAA24A` | `OBTColors.link` (text/links on tonal) |

### 1.5 The balance trio — colour **and** icon **and** label (never colour alone)

Invariant-grade accessibility rule (Haldi README): the balance signal is encoded three ways so
it survives colour-blindness and greyscale. Each branch is a token triple. Icons map to Material
Symbols Rounded → Flutter `Icons.*_rounded`.

| Signal | Colour (light / dark) | Icon | Label copy |
|---|---|---|---|
| **Positive** (you are owed) | `#0F7D6B` / `#34C0A4` | `Icons.arrow_upward` (rounded) | "owes you" / "you are owed" |
| **Negative** (you owe) | `#BC4030` / `#F2856B` | `Icons.arrow_downward` (rounded) | "you owe" |
| **Zero** (settled) | `#6F6557` / `#A99C8C` | `Icons.check` (rounded) | "Settled up" |

This triple is reified as the **balance pill** shared component (§4, new component 2). No screen
may emit a balance using colour alone.

### 1.6 Category palette — 8 colour-blind-safe hues (chip bg at ~10% opacity)

A luminance-spread, colour-blind-safe set (≥3:1 on surface). **Chip/tile backgrounds use the hue
at ~10% opacity** (`hue + "1A"`, i.e. `Color(0x1A……)` or `hue.withValues(alpha: 0.10)`); the
icon uses the **full** hue. Lives in `OBTColors` as an 8-entry category map keyed by the domain
category enum.

| Category | Light | Dark | Icon (Material Symbols → `Icons.*`) |
|---|---|---|---|
| Food & Drink | `#E8762B` | `#F59A52` | `restaurant` |
| Transport | `#2E78C9` | `#5B9BE8` | `directions_bus` / `directions_car` |
| Groceries | `#4FA13E` | `#73C463` | `local_grocery_store` |
| Entertainment | `#B5489B` | `#D470BC` | `movie` |
| Rent & Housing | `#6C4FC9` | `#9079E6` | `home` |
| Utilities | `#1FA39A` | `#3EC9BF` | `bolt` |
| Shopping | `#D94F87` | `#F074A6` | `shopping_bag` |
| Other | `#8A7B6B` | `#A99986` | `category` |

---

## 2. Shape, elevation and motion tokens

### 2.1 Corner radii

Current `theme.dart` exposes three radii (`radiusMedium = 12`, `radiusLarge = 16`,
`radiusXL = 24`) and applies `radiusLarge` to `CardTheme`. The Haldi scale is wider; the plan
introduces a named scale and re-points `CardTheme`:

| Token | Value | Haldi range | Applies to |
|---|---|---|---|
| `radiusChipInput` | `12` | 12–14 | Chips, text inputs (keeps current `radiusMedium`). |
| `radiusButton` | `16` | 14–16 | Buttons (was 12). |
| `radiusCard` | `20` | 16–22 | Cards, list tiles, hero card (bump `CardTheme` 16 → 20). |
| `radiusPill` | `18` | 18–19 | FAB and pill controls. |
| `radiusSheet` | `28` | 26–28 | Bottom-sheet **top** corners only (was `radiusXL` 24). |
| `radiusFull` | `999` | 999 | Fully-rounded pills, avatars, balance pill. |

### 2.2 Elevation and the soft-warm shadow model

Haldi uses **soft, warm shadows, never hard borders** in light, and **flips to 1px outline
borders in dark**. Flutter's default `Material` elevation casts a neutral-grey shadow, so the
plan is a small shared `OBTShadows` helper (a set of `BoxShadow` lists) applied to container
decorations, with `Card`/`Material` `elevation: 0` to suppress the default:

| Surface | Light | Dark |
|---|---|---|
| Row / list tile | `0 1px 3px rgba(42,33,27,.05)` | **no shadow** — 1px `outline` (`#3A322A`) border |
| Hero / elevated card, FAB | `0 12px 30px -12px rgba(224,146,46,.30)` (marigold-tinted) | `0 8px 22px -10px rgba(0,0,0,.60)` + 1px `outline` border |

Screen gutters 18–22 px; row vertical padding 10–13 px; tap targets ≥ 44 pt iOS / 48 dp Android
(already met by Material defaults and the existing `OBTBottomNav`/`OBTFloatingActionButton`).

### 2.3 Motion

Defaults: **200–300 ms, ease-in-out.** Specifics, with the Flutter mechanism each maps to:

| Motion | Spec | Flutter mechanism (PR #1 sets the defaults) |
|---|---|---|
| Page push/pop | slide + fade, ~280 ms | `PageTransitionsTheme` (custom builder) on both themes. |
| Bottom sheet | spring up, grabber handle | `showModalBottomSheet` with a drag handle + spring curve. |
| FAB press | scale `0.92 → 1.04 → 1` spring | press-scale wrapper on `OBTFloatingActionButton` (currently deferred). |
| List entrance | stagger 30 ms/row | staggered `AnimatedList`/interval animations at list sites. |
| Skeleton → content | cross-fade | `AnimatedSwitcher` from skeleton (§4, component 1) to content. |
| Success | check pop + success haptic | success moment in the settle-up sheet (§4, component 6) + `HapticFeedback`. |
| **Reduced motion** | instant cross-fades | honour `MediaQuery.disableAnimations` / `accessibleNavigation` → durations collapse to ~0 and transitions become instant cross-fades. **This is an accessibility requirement, not a nicety.** |

---

## 3. Typography swap — Bricolage Grotesque + Hanken Grotesk

### 3.1 The swap

Replace the two families in `_buildTextTheme`:

- `GoogleFonts.plusJakartaSans()` (headings) → **`GoogleFonts.bricolageGrotesque()`** —
  display/headings; **tabular figures for ALL amounts** (`FontFeature.tabularFigures()`).
- `GoogleFonts.inter()` (body/UI) → **`GoogleFonts.hankenGrotesk()`** — text/UI.

Both ship via `google_fonts` (already a dependency). Flutter Dev must confirm the pinned
`google_fonts` version exposes `bricolageGrotesque` and `hankenGrotesk`; both are on Google
Fonts. Haldi permits bundling the `.ttf` as the fallback embedding strategy if a runtime fetch
is undesirable.

### 3.2 Current `TextTheme` structure (the swap target — for a precise mapping)

`_buildTextTheme(base)` currently sets thirteen slots. Recording them so the migration is a
slot-for-slot edit, not a rewrite:

| Slot | Current font | Wt | Size / LH | Tracking |
|---|---|---|---|---|
| `displayLarge` | Plus Jakarta | 700 | 34 / 40 | −0.25 |
| `displayMedium` | Plus Jakarta | 700 | 28 / 34 | −0.15 |
| `headlineLarge` | Plus Jakarta | 600 | 24 / 30 | 0 |
| `headlineMedium` | Plus Jakarta | 600 | 20 / 26 | 0 |
| `titleLarge` | Plus Jakarta | 600 | 18 / 24 | 0 |
| `titleMedium` | Plus Jakarta | 500 | 16 / 22 | 0.1 |
| `titleSmall` | Plus Jakarta | 500 | 14 / 20 | 0.1 |
| `bodyLarge` | Inter | 400 | 16 / 24 | 0.15 |
| `bodyMedium` | Inter | 400 | 14 / 20 | 0.15 |
| `bodySmall` | Inter | 400 | 12 / 16 | 0.2 |
| `labelLarge` | Inter | 500 | 14 / 20 | 0.1 |
| `labelMedium` | Inter | 500 | 12 / 16 | 0.5 |
| `labelSmall` | Inter | 500 | 10 / 12 | 0.5 |

### 3.3 Haldi role → Flutter slot map (the target)

Tracking is expressed in logical px (Flutter `letterSpacing`); Haldi gives it in em, converted
at the listed size (e.g. Bricolage −0.01em at 48 px = −0.48).

| Haldi role | Font | Wt | Size / LH | Tracking (px) | Flutter slot |
|---|---|---|---|---|---|
| Amount-hero | Bricolage (tabular) | 700 | 48 / 48 (1.0) | −0.48 | `displayLarge` |
| H1 large title | Bricolage | 700 | 32 / 38 | −0.32 | `displayMedium` |
| H2 screen/sheet title | Bricolage | 700 | 24 / 30 | −0.24 | `headlineLarge` |
| H3 section | Bricolage | 600 | 19 / 26 | 0 | `headlineMedium` |
| Title / row name | Hanken | 700 | 16 / 22 | 0 | `titleLarge` |
| Title / row name (sm) | Hanken | 700 | 14 / 20 | 0 | `titleMedium` |
| Amount-row | Bricolage (tabular) | 700 | 16 / 20 | 0 | `titleSmall` *(amount-typed; see note)* |
| Body | Hanken | 400/500 | 15 / 22 | 0 | `bodyLarge` |
| Body-sm | Hanken | 400 | 13 / 18 | 0 | `bodyMedium` |
| Caption / meta | Hanken | 500 | 12 / 16 | 0.12 | `bodySmall` |
| Button | Hanken | 700 | 16 / 20 | 0.16 | `labelLarge` |
| Overline / kicker | Hanken | 700 | 11 / 14 | 1.32, UPPERCASE | `labelMedium` |
| (smallest UI) | Hanken | 500 | 11 / 14 | 0.5 | `labelSmall` |

**Amounts are a cross-cutting style, not just one slot.** Amount-hero (`displayLarge`) and
Amount-row both use Bricolage with `FontFeature.tabularFigures()`, but amounts also appear inside
rows, summaries and the settle-up sheet. The plan is a shared text-style helper (e.g.
`OBTText.amount(context)` / `OBTText.amountHero(context)`) that returns the Bricolage-tabular
style, applied at every amount site **in addition to** the global slots. This keeps digits
column-aligned everywhere and keeps amount rendering co-located with the `formatInrFromPaise()`
boundary (§5).

Note two deliberate family shifts from the old theme: `titleLarge`/`titleMedium` move from a
heading face to **Hanken** (Haldi makes row names a text-face role), and `titleSmall` becomes a
Bricolage tabular **amount** style. Screens that used these slots for headings should move to
`headline*`; this is captured per-screen in `02-conversion-checklist.md`.

---

## 4. Shared-widget impact

### 4.1 Existing shared widgets — reskin vs change

Verdict: **all six existing shared widgets are reskins (token/type only). None requires a
structural rebuild.** Two carry an *optional* motion/affordance enhancement that is polish, not a
contract change. This is the reassuring headline of the foundation: the existing catalogue
survives the visual change intact.

| Widget (path) | Classification | What changes | What stays |
|---|---|---|---|
| `OBTBottomNav` (`core/widgets/nav/`) | **Reskin** | Active tint → `primary` marigold; filled/outlined icon pair stays; label type → Hanken caption; selected/unselected colours from new scheme. | 5-tab structure, fixed type, telemetry tokens, tap targets. *Optional structural follow-up:* the Haldi active-pill needs Material 3 `NavigationBar` (the current `BottomNavigationBar` cannot draw it) — decide in the nav conversion PR; not required for the foundation. |
| `OBTFloatingActionButton` (`core/widgets/nav/`) | **Reskin** | `backgroundColor` `secondary` → **`primary`** marigold; `foregroundColor` `Colors.white` → **`onPrimary` ink** (§1.2); radius → `radiusPill` 18. | `Icons.add`, hero-tag contract, semantic label, 56 dp target. *Optional:* the press-spring (§2.3) — currently deferred. |
| `OBTAmountInput` (`core/widgets/inputs/`) | **Reskin** | Amount text → Bricolage tabular (`OBTText.amount`); `₹` prefix colour → `primary`; field radius → `radiusChipInput`; error text → `error` token. | **All paise logic, the formatter, the `onChanged(int paise)` contract — untouched (Invariant 1).** |
| `OBTActivityRow` (`core/widgets/lists/`) | **Reskin** | Event-icon colours → Haldi semantics; trailing amount → Bricolage tabular; primary/secondary text type → Hanken; leading avatar tint from new scheme. | Row layout, 56 dp min height, semantics, `formatInrFromPaise()` boundary. |
| `OBTConfirmationDialog` (`core/widgets/dialogs/`) | **Reskin** | Dialog radius → `radiusCard`; destructive confirm uses `error`/`onError` (ink per §1.3); button type → Hanken button. | Confirm/cancel structure, destructive semantics, back/escape-as-cancel. |
| `OBTSettleUpCard` (`features/friends/.../widgets/`) | **Reskin** | Card fill → `surfaceVariant` hero tone; arrow → marigold; amount → Bricolage tabular; CTA radius/type; cooldown caption → `textTertiary`. | Directional/countdown logic, avatar stack, `formatInrFromPaise()` boundary, deferred extraction note. |

### 4.2 New components the Haldi catalogue requires (do not exist yet)

Thirteen net-new shared components/asset-holders. One line each, with the Haldi screen(s) that
need them. (The authoritative per-screen build list is Phase 2,
`02-conversion-checklist.md`; this is the shared-foundation subset.)

1. **Skeleton loader set** — shimmer placeholders for the loading state (Haldi mandates
   skeletons, not spinners). Screens 6, 9, 11, 16, 21, 23, 25 + add-friend lookup (10).
2. **Balance pill** — the §1.5 colour+icon+label trio as a reusable chip. Screens 6, 9, 11, 16.
3. **Category chip / category tile** — full-hue icon on a 10%-opacity hue bed (§1.6). Screens 7
   (filters), 21 (step 1), 22 (detail), 6 (legend).
4. **3-step Add-expense bottom sheet shell** — grabber + stepper + per-step validation host.
   Screen 21 (global overlay).
5. **Segmented split-method control** — Equally / Unequal / % / Shares / Exact, with live
   "adds up" (green) vs over/under (red, Next disabled) sum validation. Screen 21 (step 2).
6. **Settle-up bottom sheet** — pre-filled recipient + amount, editable amount, the disabled
   "Pay via UPI" slot, success moment (haptic). Screen 23 (global overlay).
7. **Empty-state scaffold** — flat illustration holder + headline + one CTA. Empties on 6, 9,
   14, 24, 25.
8. **Offline / pending-sync banner** — global overlay across all surfaces.
9. **Monthly-spend donut + 6-category legend** — `fl_chart` styling per ADR-0017. Screen 6.
10. **Group segmented tab bar** — Expenses / Balances / Activity. Screen 16.
11. **OTP six-box auto-advance input** — 6 digits, auto-advance, resend cooldown. Screen 4.
12. **Stacked-avatar cluster** — group member stacks + admin badge. Screens 14, 18.
13. **Brand kit** — the `÷` logo mark, "One**By**Two" wordmark, splash marigold gradient, and
    the onboarding illustration holders. Screens 1, 2.

The disabled "Make recurring" toggle in component 4 (step 3) and the disabled "Pay via UPI" row
in component 6 are the inert extension slots (§5) — present, tagged "Coming soon", **not wired**.

---

## 5. Invariant preservation

The foundation is **visual only**; it touches no backend contract. Each of the four invariants
is preserved, and the three disabled extension slots stay inert.

1. **Money is integer paise.** Stored/transmitted values remain integer `*Paise`. Rupee strings
   are produced **only** by `formatInrFromPaise()` (`lib/core/formatters/inr_formatter.dart`),
   the sole paise→rupee boundary. The typography change restyles amount *rendering* (Bricolage
   tabular via `OBTText.amount`) but never introduces `paise / 100` arithmetic and never changes
   the stored value. `OBTAmountInput`'s `onChanged(int paise)` contract is untouched.
2. **`simplifiedBalances` is server-written / client-read-only.** No new widget writes the field;
   the balance pill and settle-up components **read** the server projection only. The UI rule is
   unchanged: **simplified debts only — settle-up shows ONE pre-filled suggested payment
   (recipient + amount); never a raw who-paid-whom debt graph.** Component 6 (settle-up sheet)
   and the Group "Balances" tab (component 10) render the single suggested payment / minimum
   transfer set, not a debt web.
3. **OS system share sheet only.** Invite affordances (friends/groups) keep delegating to the
   platform share sheet via the existing `share_service.dart`. No WhatsApp/SMS/single-app button
   is added by any new component.
4. **Single Firebase project.** Unchanged — a theme/token migration has no project or
   configuration surface. All pre-merge testing stays on the Emulator Suite.

**No backend artefact changes as a result of this plan:** `firestore.rules`, `storage.rules`,
`firestore.indexes.json`, the Firestore schema, the Cloud Functions, and the simplified-debts
algorithm are all out of scope and untouched. The three disabled extension slots — Settle Up →
"Pay via UPI", Add Expense step 3 → "Make recurring", Profile → Notifications → "Language" —
ship visually present but inert ("Coming soon"); building any of them live would be a defect.

---

## 6. Hand-offs

- **Flutter Dev** implements Sprint 3 PR #1 against `lib/app/theme.dart` (the `ColorScheme`, the
  `OBTColors` extension, the Bricolage/Hanken `TextTheme`, the radius/shadow/motion tokens, the
  `OBTText` amount helper) and the six shared-widget reskins. Architect reviews the token/slot
  fidelity against §1–§3; Flutter UI code itself is Flutter Dev's remit.
- **QA** (`04-qa-test-strategy.md`) owns the contrast gate (the §1.2/§1.3 ink pairings), the
  dynamic-type-to-2.0× check, and the light+dark golden set for the six reskinned widgets and the
  thirteen new components.
- **PM** carries the SRS §6.2/§6.3 reconciliation as a separate `update-srs` proposal; this plan
  and ADR-0024 do not edit the SRS.

**Adoption decision:** `.github/shared/decision-log.md` → **ADR-0024**.
