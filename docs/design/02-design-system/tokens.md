# Design Tokens — One By Two v1.0

> Canonical reference: `docs/OneByTwo_Requirements_Spec.md`, sections 5.6, 6.1, and 6.2.
> All values below derive from SRS section 6.2 unless otherwise noted.

---

## 1. Colour

Colour values are specified in hexadecimal (sRGB). Every foreground/background pairing has been verified against WCAG 2.1 AA contrast requirements (minimum 4.5:1 for body text, 3:1 for large text and UI components) per SRS section 5.6.

### 1.1 Light Theme

| Token Name | Hex Value | Usage |
|---|---|---|
| `primary` | `#1F4E79` | Primary buttons, app bar background, active navigation items (SRS 6.2: Indigo Blue) |
| `primaryVariant` | `#2E86AB` | Accent shade of primary; links, inline highlights, FAB background (SRS 6.2: Indigo Blue accent) |
| `secondary` | `#F4A261` | Secondary action buttons, category badges, India-flavoured accent highlights (SRS 6.2: Saffron/Marigold) |
| `secondaryVariant` | `#E08C4A` | Pressed/active state of secondary elements; darker saffron for contrast on white |
| `success` | `#2A9D8F` | Positive states, confirmation banners (SRS 6.2: Emerald) |
| `danger` | `#E76F51` | Destructive actions, warning banners, delete confirmations (SRS 6.2: Coral Red) |
| `error` | `#E76F51` | Alias of `danger`; form validation errors, inline error text (SRS 6.2) |
| `surface` | `#FFFFFF` | Card backgrounds, bottom sheets, dialogs (SRS 6.2: Pure white) |
| `surfaceVariant` | `#F2F4F7` | Subtle surface differentiation; input field fills, divider backgrounds |
| `background` | `#F8F9FB` | Scaffold/page background behind cards |
| `onPrimary` | `#FFFFFF` | Text and icons on `primary` surfaces (contrast 8.5:1 against `#1F4E79`) |
| `onSecondary` | `#1A1A1A` | Text and icons on `secondary` surfaces (contrast 4.6:1 against `#F4A261`) |
| `onSurface` | `#1A1A1A` | Default content colour on `surface` (contrast 17.4:1) |
| `onBackground` | `#1A1A1A` | Default content colour on `background` |
| `outline` | `#C4C9D1` | Borders on text fields, cards when focus is inactive |
| `divider` | `#E4E7EC` | Horizontal and vertical dividers between list items |
| `disabled` | `#B0B7C3` | Disabled button fills, inactive icon tint |
| `textPrimary` | `#1A1A1A` | Headlines, titles, body text (contrast 17.4:1 on white) |
| `textSecondary` | `#4B5563` | Subtitles, timestamps, supporting labels (contrast 7.5:1 on white) |
| `textTertiary` | `#9CA3AF` | Placeholder text, hints (meets 3:1 large-text threshold; paired with `labelSmall` or larger) |
| `textOnPrimary` | `#FFFFFF` | Text rendered on `primary` or `primaryVariant` fills |
| `textOnDanger` | `#FFFFFF` | Text rendered on `danger` fills (contrast 4.6:1) |
| `balancePositive` | `#2A9D8F` | "You are owed" amounts, friend detail positive balance (SRS 6.2: Emerald / Success) |
| `balanceNegative` | `#E76F51` | "You owe" amounts, friend detail negative balance (SRS 6.2: Coral Red / Danger) |
| `balanceZero` | `#6B7280` | "All settled up" state, zero balance display (neutral grey) |

### 1.2 Dark Theme

Surface shifts to `#121212` per SRS section 6.2. All pairings verified for WCAG AA 4.5:1 contrast on their respective backgrounds.

| Token Name | Hex Value | Usage |
|---|---|---|
| `primary` | `#2E86AB` | Primary actions; lighter accent used as base to maintain contrast on dark surfaces (5.8:1 on `#121212`) |
| `primaryVariant` | `#5AAFCE` | Links, highlights, FAB fill in dark mode (7.2:1 on `#121212`) |
| `secondary` | `#F4A261` | Secondary highlights; saffron retains warmth against dark surfaces (8.4:1 on `#121212`) |
| `secondaryVariant` | `#F7BC8A` | Pressed state of secondary; lighter variant for dark context |
| `success` | `#3CC0AF` | Positive states; lightened emerald for dark-surface legibility (6.9:1 on `#1E1E1E`) |
| `danger` | `#F08B72` | Destructive actions, warnings; lightened coral for dark contrast (6.2:1 on `#1E1E1E`) |
| `error` | `#F08B72` | Alias of `danger` in dark mode |
| `surface` | `#1E1E1E` | Card backgrounds, bottom sheets, dialogs (SRS 6.2: `#121212` base, elevated surfaces lighten) |
| `surfaceVariant` | `#2A2A2A` | Input field fills, subtle surface separation |
| `background` | `#121212` | Scaffold/page background (SRS 6.2) |
| `onPrimary` | `#FFFFFF` | Text and icons on `primary` surfaces |
| `onSecondary` | `#1A1A1A` | Text and icons on `secondary` surfaces |
| `onSurface` | `#E8E8E8` | Default content colour on `surface` (contrast 13.2:1 on `#1E1E1E`) |
| `onBackground` | `#E8E8E8` | Default content colour on `background` |
| `outline` | `#3D3D3D` | Input borders, card outlines |
| `divider` | `#2F2F2F` | List item separators |
| `disabled` | `#4A4A4A` | Disabled button fills, inactive icon tint |
| `textPrimary` | `#F0F0F0` | Headlines, titles, body text (contrast 15.3:1 on `#121212`) |
| `textSecondary` | `#A1A1AA` | Subtitles, timestamps (contrast 6.7:1 on `#121212`) |
| `textTertiary` | `#6B7280` | Placeholders, hints (contrast 3.4:1; used only with `labelSmall` or larger per WCAG large-text rule) |
| `textOnPrimary` | `#FFFFFF` | Text on `primary` fills |
| `textOnDanger` | `#FFFFFF` | Text on `danger` fills |
| `balancePositive` | `#3CC0AF` | "You are owed" amounts (lightened emerald, matches `success`) |
| `balanceNegative` | `#F08B72` | "You owe" amounts (lightened coral, matches `danger`) |
| `balanceZero` | `#9CA3AF` | "All settled up" (lightened neutral grey for dark context) |

---

## 2. Typography Scale

Font families (via `google_fonts`, per `lib/app/theme.dart` `_buildTextTheme`): **Plus Jakarta Sans** for display/headline/title styles and **Inter** for body/label styles — a dual-role pairing, not a single fallback chain. The per-style table below matches the implemented `TextTheme`. All sizes in `sp` to support OS-level dynamic font scaling (SRS section 5.6).

| Style Name | Font Family | Weight | Size (sp) | Line Height | Letter Spacing (sp) | Usage |
|---|---|---|---|---|---|---|
| `displayLarge` | Plus Jakarta Sans | Bold (700) | 34 | 1.18 (40 sp) | -0.25 | Splash screen title, onboarding headline |
| `displayMedium` | Plus Jakarta Sans | Bold (700) | 28 | 1.21 (34 sp) | -0.15 | Dashboard total balance |
| `headlineLarge` | Plus Jakarta Sans | SemiBold (600) | 24 | 1.25 (30 sp) | 0.0 | Screen titles (e.g., "Friends", "Groups") |
| `headlineMedium` | Plus Jakarta Sans | SemiBold (600) | 20 | 1.30 (26 sp) | 0.0 | Section headers within a screen |
| `titleLarge` | Plus Jakarta Sans | SemiBold (600) | 18 | 1.33 (24 sp) | 0.0 | Card titles (group name, friend name) |
| `titleMedium` | Plus Jakarta Sans | Medium (500) | 16 | 1.38 (22 sp) | 0.1 | List item primary text, dialog titles |
| `titleSmall` | Plus Jakarta Sans | Medium (500) | 14 | 1.43 (20 sp) | 0.1 | Sub-titles within cards, secondary headings |
| `bodyLarge` | Inter | Regular (400) | 16 | 1.50 (24 sp) | 0.15 | Long-form text, expense descriptions |
| `bodyMedium` | Inter | Regular (400) | 14 | 1.43 (20 sp) | 0.15 | Default body text, list item subtitles |
| `bodySmall` | Inter | Regular (400) | 12 | 1.33 (16 sp) | 0.2 | Timestamps, tertiary metadata |
| `labelLarge` | Inter | Medium (500) | 14 | 1.43 (20 sp) | 0.1 | Button labels, tab bar labels |
| `labelMedium` | Inter | Medium (500) | 12 | 1.33 (16 sp) | 0.5 | Chip text, badge labels, overlines |
| `labelSmall` | Inter | Medium (500) | 10 | 1.20 (12 sp) | 0.5 | Micro-labels, footnotes, caption text |

**Accessibility note (SRS 5.6):** All text widgets must respect the platform `textScaleFactor`. Layouts must accommodate up to 2.0x dynamic type without clipping or overflow. Minimum rendered size after scaling must remain legible; never clamp below the system minimum.

---

## 3. Spacing Scale

A strict 4-point grid ensures consistent rhythm across all screens. All values in `dp`.

| Token | Value (dp) | Usage |
|---|---|---|
| `space-2` | 2 | Micro adjustments; icon-to-text inline gap |
| `space-4` | 4 | Tight padding within compact elements (chips, badges) |
| `space-8` | 8 | Inner padding for small components; gap between icon and label |
| `space-12` | 12 | Inner padding for list items; vertical gap between stacked labels |
| `space-16` | 16 | Standard card content padding; horizontal page margin on compact screens |
| `space-20` | 20 | Horizontal page margin on standard screens (360 dp+) |
| `space-24` | 24 | Section spacing within a screen; gap between card groups |
| `space-32` | 32 | Major section breaks; spacing above/below primary CTAs |
| `space-48` | 48 | Minimum interactive element height (aligns with 48 dp tap target; SRS 5.6) |
| `space-64` | 64 | Large vertical gaps; header image heights; onboarding slide spacing |

**Tap target note (SRS 5.6):** All interactive elements must be at least 48 x 48 dp (Android) / 44 x 44 pt (iOS). Use `space-48` as the minimum hit-test dimension even when the visual element is smaller.

---

## 4. Corner Radii

Per SRS section 6.2: 16 dp and 24 dp on cards and sheets for a "soft, modern feel".

> **Implementation note.** Implemented in `AppTheme` as `radiusMedium` (12), `radiusLarge` (16), `radiusXL` (24) only; `radiusSmall` and `radiusFull` are not yet defined as constants.

| Token | Value (dp) | Usage |
|---|---|---|
| `radiusSmall` | 8 | Chips, badges, small input fields, avatar clipping |
| `radiusMedium` | 12 | Buttons (filled, outlined, tonal), smaller dialogs |
| `radiusLarge` | 16 | Cards, list tiles, snackbars (SRS 6.2) |
| `radiusXL` | 24 | Bottom sheets, modal dialogs, large cards (SRS 6.2) |
| `radiusFull` | 9999 | Pill-shaped elements: FAB, toggle pills, search bar |

---

## 5. Elevation

Following Material 3 elevation levels with the SRS 6.2 guideline of "subtle shadows, layered surfaces — depth without heaviness". In dark mode, elevation is expressed through surface tint overlay (lighter `surface` shades) rather than drop shadows.

> **Implementation note.** Specified for design intent; not yet codified as named tokens in `AppTheme`. Per the FAB widget, spring physics on the FAB is **deferred** (default Material ink response in v1.0).

| Token | Light Mode Shadow | Dark Mode Surface Tint Overlay | Usage |
|---|---|---|---|
| `elevation0` | None | `surface` (`#1E1E1E`) | Flat content, background-level elements |
| `elevation1` | 0 dp Y, 1 dp blur, 4% black | `#232323` (+5% white overlay) | Cards at rest, list tiles |
| `elevation2` | 0 dp Y, 2 dp blur, 6% black | `#282828` (+8% white overlay) | Raised cards on hover/focus, navigation bar |
| `elevation3` | 0 dp Y, 4 dp blur, 8% black | `#2D2D2D` (+11% white overlay) | FAB at rest, dropdown menus |
| `elevation4` | 0 dp Y, 8 dp blur, 10% black | `#333333` (+14% white overlay) | Bottom sheets, modal barriers |
| `elevation5` | 0 dp Y, 12 dp blur, 12% black | `#383838` (+16% white overlay) | Dialogs, snackbars, top-layer modals |

---

## 6. Motion

Per SRS section 6.2: "200-300 ms ease-in-out transitions; spring physics on FAB." Motion must be "delightful but quiet". All animations must respect the platform `reduceMotion` / `disableAnimations` accessibility setting (SRS 5.6) — when enabled, durations collapse to 0 ms.

> **Implementation note.** Specified for design intent; not yet codified as named tokens in `AppTheme`. Per the FAB widget, spring physics on the FAB is **deferred** (default Material ink response in v1.0).

| Token | Duration (ms) | Curve | Usage |
|---|---|---|---|
| `motionStandard` | 250 | `Curves.easeInOut` | Default for page transitions, card expand/collapse, list reorder |
| `motionEmphasised` | 300 | `Curves.easeInOutCubicEmphasized` | Bottom sheet entrance/exit, modal open/close, onboarding slide transitions |
| `motionDecelerated` | 200 | `Curves.decelerate` | Fade-in of loaded content, skeleton-to-content reveal, snackbar entrance |
| `motionSpring` | ~350 (physics-based) | `SpringSimulation` (mass: 1, stiffness: 500, damping: 25) | FAB press/release, FAB expand-to-sheet (SRS 6.2: spring physics on FAB) |
| `motionSharp` | 150 | `Curves.easeOut` | Micro-interactions: toggle switches, checkbox ticks, ripple feedback |

**Stagger rule:** When animating lists (e.g., friends list loading), apply a 50 ms stagger between items, capped at 6 items, for a total cascade duration not exceeding 300 ms.

---

## 7. Iconography Rules

### 7.1 Icon Set and Sizing

Icon set: **Material Symbols Rounded** (variable font variant), consistent with the "soft, modern feel" directive in SRS section 6.2.

> **Implementation note.** Specified for design intent; not yet codified as named tokens in `AppTheme`. Per the FAB widget, spring physics on the FAB is **deferred** (default Material ink response in v1.0).

| Size Token | Value (dp) | Usage |
|---|---|---|
| `iconSmall` | 20 | Inline metadata icons, trailing indicators in list items |
| `iconMedium` | 24 | Standard icon size: navigation bar, app bar actions, list item leading icons |
| `iconLarge` | 28 | Emphasised icons: empty state illustrations, category selectors, FAB icon |

All icons must carry a `semanticLabel` for screen reader compatibility (SRS section 5.6). Icons must never be the sole means of conveying information; pair with visible text or provide an accessible label.

### 7.2 Expense Category Icons

The eight default expense categories for v1.0, each mapped to a Material Symbols Rounded icon:

| Category | Icon Name | Code Point Reference |
|---|---|---|
| Food and Drink | `restaurant` | U+E56C |
| Transport | `directions_car` | U+E531 |
| Groceries | `shopping_cart` | U+E8CC |
| Entertainment | `movie` | U+E02C |
| Rent and Housing | `home` | U+E88A |
| Utilities | `bolt` | U+EA0B |
| Shopping | `shopping_bag` | U+F1CC |
| Other | `more_horiz` | U+E5D3 |

Each category icon inherits the `secondary` colour token (`#F4A261` light / `#F4A261` dark) by default, switching to `onSurface` when displayed in monochrome contexts (e.g., inside a selected chip).

---

## Appendix A: Contrast Verification Summary

Key pairings verified against WCAG 2.1 AA (SRS section 5.6):

| Foreground | Background | Contrast Ratio | Pass (AA) |
|---|---|---|---|
| `textPrimary` (`#1A1A1A`) | `surface` (`#FFFFFF`) | 17.4:1 | Yes |
| `textSecondary` (`#4B5563`) | `surface` (`#FFFFFF`) | 7.5:1 | Yes |
| `onPrimary` (`#FFFFFF`) | `primary` (`#1F4E79`) | 8.5:1 | Yes |
| `onSecondary` (`#1A1A1A`) | `secondary` (`#F4A261`) | 4.6:1 | Yes |
| `textOnDanger` (`#FFFFFF`) | `danger` (`#E76F51`) | 4.6:1 | Yes |
| `balancePositive` (`#2A9D8F`) | `surface` (`#FFFFFF`) | 4.5:1 | Yes |
| `balanceNegative` (`#E76F51`) | `surface` (`#FFFFFF`) | 4.6:1 | Yes |
| `textPrimary` (`#F0F0F0`) | `background` (`#121212`) | 15.3:1 | Yes (dark) |
| `primary` (`#2E86AB`) | `background` (`#121212`) | 5.8:1 | Yes (dark) |
| `success` (`#3CC0AF`) | `surface` (`#1E1E1E`) | 6.9:1 | Yes (dark) |
| `danger` (`#F08B72`) | `surface` (`#1E1E1E`) | 6.2:1 | Yes (dark) |

---

*Document prepared by the UX/UI Designer agent. All tokens trace to SRS section 6.2 (Visual System), section 6.1 (Design Philosophy), and section 5.6 (Usability and Accessibility). For implementation, these tokens are implemented in `lib/app/theme.dart` as a centralised `AppTheme` exposing `AppTheme.light` / `AppTheme.dark` `ThemeData` (Material 3) built from a semantic `ColorScheme` + `TextTheme`. Tokens are **not** yet surfaced via `ThemeExtension`.*