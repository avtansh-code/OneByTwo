# Design System — Extension Points

> **Document owner:** UX/UI Designer
> **Version:** 1.0
> **Status:** Draft — pending Flutter Dev review
> **Audience:** Flutter Developer, Solution Architect, Product Manager

---

## Purpose

This document catalogues named seams in the v1.0 design system where post-v1.0 features (SRS section 12.3) will require new tokens, components, or interaction patterns. The v1.0 design system must not preclude any of these additions. Each extension point identifies what the current design system provides, what the future feature demands, and — critically — what must not be hardcoded in v1.0 to preserve extensibility.

This document is the design-system counterpart to the Information Architecture extension points defined in `docs/design/01-information-architecture/extension-points.md`. Where that document addresses navigation, flows, and screen structure, this document addresses visual tokens, component variants, and interaction patterns.

All features referenced below are explicitly out of scope for v1.0 (SRS section 12.3). No design or implementation work for these features shall occur in v1.0. This catalogue exists solely to ensure the v1.0 design system is structured so that these additions can be made without refactoring existing tokens, components, or motion definitions.

Note: design tokens currently live in `lib/app/theme.dart` as a plain `AppTheme` (semantic `ColorScheme`/`TextTheme`), **not** a token map / `ThemeExtension`. DS-EXT-01's 'reference fonts by semantic name via a token map' therefore remains a v1.1 prerequisite not yet in place.

---

## Extension Points

### DS-EXT-01: Hindi Font Fallback Stack

| Field | Detail |
|---|---|
| **ID** | DS-EXT-01 |
| **Feature** | Hindi and other Indian-language localisations (SRS section 12.3, bullet 2) |
| **Category** | Token |
| **Corresponding IA extension** | IA-EXT-03 (Language selector row) |
| **What v1.0 provides** | The typography token specifies Inter or Plus Jakarta Sans for Latin glyphs, with a fallback to the platform system font (SRS section 6.2). All user-facing strings are externalised via `.arb` files with `en` as the sole locale (SRS section 5.9). |
| **What v1.1 adds** | Noto Sans Devanagari (or an equivalent open-source Devanagari typeface) is inserted into the font fallback stack immediately after the Latin primary face. Additional Indic script faces (e.g., Noto Sans Tamil, Noto Sans Bengali) may follow for further language support. Font weights must match the Latin face: Regular (400), Medium (500), SemiBold (600), Bold (700). |
| **Design system impact** | Typography tokens must reference fonts by semantic name (e.g., `fontFamily.body`, `fontFamily.heading`), not by hardcoded family string. The `TextTheme` definition must be constructed from a token map so that adding a new fallback face requires only a token change, not a widget-level refactor. Line-height tokens must accommodate Devanagari's taller ascenders and descenders — v1.0 line-height values must be set generously enough (minimum 1.4x for body text) that Devanagari text does not clip without adjustment. |

---

### DS-EXT-02: RecurrenceChip Component

| Field | Detail |
|---|---|
| **ID** | DS-EXT-02 |
| **Feature** | Recurring expenses and subscription splits (SRS section 12.3, bullet 3) |
| **Category** | Component |
| **Corresponding IA extension** | IA-EXT-02 (Recurring expense toggle) |
| **What v1.0 provides** | The component library includes a base `Chip` widget used for category labels and split-method indicators on expense cards. Chips support a label, an optional leading icon, and colour variants mapped to the existing semantic palette (Primary, Secondary, Success, Danger per SRS section 6.2). No concept of recurrence exists in the expense UI (SRS section 6.3, item 8). |
| **What v1.1 adds** | A `RecurrenceChip` variant displaying frequency labels such as "Monthly", "Weekly", "Fortnightly", or "Custom". The chip appears on expense list items and the expense detail view. It uses a new semantic colour — a muted, informational tone distinct from Success and Danger — to avoid implying a positive or negative financial state. An optional trailing icon (e.g., a circular-arrow recurrence glyph) reinforces the meaning. |
| **Design system impact** | The chip component architecture must support new variant registration without modifying the base chip widget. Specifically: (a) chip colour must be driven by a `ChipVariant` enumeration that is open for extension, not a closed set; (b) the icon slot must accept arbitrary `IconData`, not a fixed icon map; (c) a new semantic colour token (`Informational` or `Neutral-Accent`) must be reservable in the palette without conflicting with existing tokens. Corner radius on chips must inherit from the global corner-radius token (16 dp per SRS section 6.2), not be hardcoded per chip instance. |

---

### DS-EXT-03: UpiAppLogoRow Component

| Field | Detail |
|---|---|
| **ID** | DS-EXT-03 |
| **Feature** | UPI deep-link integration (SRS section 12.3, bullet 1) |
| **Category** | Component |
| **Corresponding IA extension** | IA-EXT-01 (Settle-up UPI slot) |
| **What v1.0 provides** | The Settle Up flow (SRS section 6.3, item 9) contains only the manual settlement recorder: amount input (pre-filled from simplified-debts suggestion), date picker, optional note, and a "Record Settlement" action button. No payment-method selector or third-party branding exists. The icon system uses a single icon font or SVG asset set containing only first-party glyphs (category icons, navigation icons, action icons). |
| **What v1.1 adds** | A horizontal row of tappable UPI app logos (GPay, PhonePe, Paytm, and potentially others) presented as a payment-method selector below the manual recording option. Each logo is a raster or vector asset at multiple density buckets (1x, 2x, 3x). Tapping a logo triggers a UPI deep-link intent. The row must handle a variable number of logos gracefully (horizontal scroll if more than four). |
| **Design system impact** | The icon system must support third-party app logos alongside first-party glyphs. Specifically: (a) the asset pipeline must accommodate PNG/SVG assets that are not part of the icon font, loaded from a named asset directory (e.g., `assets/logos/`); (b) logo dimensions must be governed by a design token (`iconSize.appLogo`, recommended 40x40 dp with 48x48 dp tap target per SRS section 5.6) rather than hardcoded per instance; (c) logo containers must have a consistent corner radius (8 dp, distinct from the card-level 16/24 dp) defined as a token; (d) the component must render a placeholder or initial-letter fallback if a logo asset is missing, to support future UPI apps without a code change. |

---

### DS-EXT-04: Multi-Currency Token Slot

| Field | Detail |
|---|---|
| **ID** | DS-EXT-04 |
| **Feature** | Multi-currency support (implied by SRS section 12.3 scope boundary; v1.0 is INR-only per SRS sections 1.3, 3.4, and 5.9) |
| **Category** | Token |
| **Corresponding IA extension** | None (no IA-level extension point; this is purely a formatting concern) |
| **What v1.0 provides** | All monetary values are stored as integer paise (SRS section 7.3, Invariant 1) and formatted at the UI layer using the Indian numbering system with two decimal places and the `₹` symbol prefix (SRS section 5.9). The currency formatter is a utility in `lib/core/` that produces strings such as "₹1,23,456.78". |
| **What v1.1 adds** | A currency-aware formatting system where symbol, decimal separator, thousands grouping pattern, and decimal precision are determined by a currency code (e.g., `INR`, `USD`, `EUR`). Expense and settlement models gain an optional `currencyCode` field. The UI displays the appropriate symbol and grouping for each currency. |
| **Design system impact** | Currency formatting must be parameterised, not hardcoded to INR. Specifically: (a) the currency symbol must be read from a token or configuration map keyed by currency code, not embedded as a literal `₹` in formatter logic; (b) the grouping pattern (Indian lakhs/crores vs. Western thousands) must be a function of the currency, not a global constant; (c) the `MoneyText` or equivalent display widget must accept a currency code parameter with a default of `INR`; (d) amount display widths in layouts must accommodate longer currency symbols (e.g., "AED", "CHF") without truncation — use flexible sizing, not fixed-width containers. Note: no multi-currency implementation occurs in v1.0; this point ensures the formatter architecture does not preclude it. |

---

### DS-EXT-05: RTL Layout Support

| Field | Detail |
|---|---|
| **ID** | DS-EXT-05 |
| **Feature** | Hindi and other Indian-language localisations (SRS section 12.3, bullet 2); potential future Urdu support |
| **Category** | Token / Component |
| **Corresponding IA extension** | IA-EXT-03 (Language selector row) |
| **What v1.0 provides** | English-only, left-to-right layout (SRS section 5.6, section 5.9). All screens are designed and tested in LTR orientation. Flutter's `Directionality` widget defaults to LTR. |
| **What v1.1 adds** | Support for RTL scripts (Urdu, potentially Arabic). When the user selects an RTL locale, all layouts mirror: leading/trailing edges swap, text alignment flips, directional icons (arrows, chevrons) reverse, and swipe gestures invert. Hindi itself is LTR (Devanagari script reads left-to-right), but the localisation infrastructure must support RTL locales without layout breakage. |
| **Design system impact** | All layouts must use logical properties exclusively. Specifically: (a) padding, margin, and alignment must use `start`/`end` (or `EdgeInsetsDirectional`), never `left`/`right`; (b) directional icons (back arrows, chevrons, swipe indicators) must be defined as semantic tokens (`icon.back`, `icon.forward`) that resolve to mirrored glyphs under RTL, not hardcoded to `Icons.arrow_back`; (c) row-based layouts (e.g., balance summaries showing "You owe" on one side and amount on the other) must use `MainAxisAlignment` values that respect directionality; (d) motion definitions (slide-in transitions, swipe-to-dismiss) must use directional-aware offsets. The v1.0 codebase must avoid any use of `EdgeInsets.only(left:)` or `Alignment.centerLeft` in favour of their directional equivalents. |

---

### DS-EXT-06: AI Suggestion Card

| Field | Detail |
|---|---|
| **ID** | DS-EXT-06 |
| **Feature** | AI-assisted receipt OCR and category prediction (SRS section 12.3, bullet 5) |
| **Category** | Component / Motion |
| **Corresponding IA extension** | IA-EXT-06 (Receipt OCR auto-fill) |
| **What v1.0 provides** | The Add/Edit Expense bottom sheet (SRS section 6.3, item 8) includes manual entry for amount, description, date, category (selected from eight predefined options per FR-EX-08), split method, and an optional receipt image attachment (FR-EX-05). All fields are user-authored; no auto-population exists. The card component supports standard states: default, selected, disabled, error. |
| **What v1.1 adds** | After a receipt image is attached and scanned, extracted values (amount, merchant/description, date, predicted category) are presented in an "AI Suggestion Card" — a visually distinct card state that communicates "machine-suggested, human-confirmed". Each suggested field shows: (a) the extracted value; (b) a confidence indicator (high/medium/low, mapped to colour); (c) an inline "Edit" affordance to override. The user explicitly confirms or corrects each field before saving. A subtle shimmer or pulse animation distinguishes suggested fields from manually entered ones. |
| **Design system impact** | The card component must support a `suggested` state alongside its existing states. Specifically: (a) a new semantic colour token (`Suggested` — recommended: a light-tinted variant of the Primary colour, e.g., `#1F4E79` at 10% opacity as background) must be defined for the suggestion state, distinct from Success/Danger/Informational; (b) a `ConfidenceIndicator` sub-component is needed, using a three-level colour scale (Success/Secondary/Danger maps naturally to high/medium/low confidence); (c) the card must support a mixed state where some fields are confirmed (standard styling) and others are still suggested (suggestion styling), requiring per-field state management in the card's visual presentation; (d) a `shimmer` or `pulse` motion token (duration: 1000–1500 ms, ease-in-out, looping until user interaction) must be added to the motion system — v1.0's motion tokens (200–300 ms ease-in-out per SRS section 6.2) cover transitions only, so the token namespace must accommodate looping ambient animations; (e) the "Edit" affordance on each suggested field must meet the 48x48 dp minimum tap target (SRS section 5.6). |

---

### DS-EXT-07: Helpdesk Chat Affordance

| Field | Detail |
|---|---|
| **ID** | DS-EXT-07 |
| **Feature** | Dedicated helpdesk integration — Freshdesk / Zoho Desk (SRS section 12.3, bullet 6) |
| **Category** | Component |
| **Corresponding IA extension** | IA-EXT-05 (Contact Support channel selector) |
| **What v1.0 provides** | The Profile and Settings screen (SRS section 6.3, item 11) includes a "Contact Support" action that opens the device mail client via `mailto:` with pre-filled triage metadata (FR-SH-03). If no mail client is configured, a fallback dialog displays the support email with a "Copy" button (FR-SH-04). The action is styled as a standard list tile with a leading icon and trailing chevron. |
| **What v1.1 adds** | The single "Contact Support" action becomes a channel selector presenting two options: "Email" (existing mailto flow) and "Chat with Support" (opens an embedded helpdesk widget or navigates to a helpdesk web view). The chat option may include an unread-message badge and an online/offline status indicator. |
| **Design system impact** | The settings list-tile component must support expansion into a sub-menu or a modal selector without restructuring the settings screen layout. Specifically: (a) list tiles must support a `badge` slot (positioned at trailing edge, before the chevron) for unread counts — the badge component needs a semantic colour (Danger for counts > 0, muted for zero) and must be defined as a reusable token-driven element; (b) a `StatusDot` sub-component (online: Success `#2A9D8F`, offline: neutral grey) must be accommodable in the icon or trailing slot; (c) the trailing chevron must be a semantic icon token (`icon.expand` / `icon.navigate`) so it can change from a navigation chevron to an expand/collapse chevron when the tile gains sub-items. |

---

## Cross-References

| Extension Point | SRS Sections | IA Extension Point |
|---|---|---|
| DS-EXT-01 | 5.6, 5.9, 6.2, 12.3 (bullet 2) | IA-EXT-03 |
| DS-EXT-02 | 6.2, 6.3 (item 8), 12.3 (bullet 3) | IA-EXT-02 |
| DS-EXT-03 | 5.6, 6.2, 6.3 (item 9), 12.3 (bullet 1) | IA-EXT-01 |
| DS-EXT-04 | 5.9, 7.3, 12.3 (scope boundary) | None |
| DS-EXT-05 | 5.6, 5.9, 6.2, 12.3 (bullet 2) | IA-EXT-03 |
| DS-EXT-06 | 5.6, 6.2, 6.3 (item 8), 12.3 (bullet 5) | IA-EXT-06 |
| DS-EXT-07 | 6.3 (item 11), 12.3 (bullet 6) | IA-EXT-05 |

---

## Design Principles for Extension Points

1. **Tokens, not literals.** Every visual property that a future feature will need to vary — colour, font family, icon glyph, corner radius, animation duration — must be expressed as a named design token in v1.0. Hardcoded literals in widget code are the primary barrier to extensibility.

2. **Open variant sets.** Component variants (chip types, card states, icon categories) must be modelled as extensible enumerations or registries, not closed `switch` statements with a `default: throw`. Adding a new variant must not require modifying the base component's source.

3. **Logical over physical.** All directional properties must use logical coordinates (`start`/`end`, `leading`/`trailing`) so that RTL support (DS-EXT-05) requires zero layout refactoring.

4. **Semantic naming.** Tokens are named by purpose (`colour.success`, `font.body`, `icon.back`), never by value (`colour.green`, `font.inter`, `icon.arrowLeft`). This ensures that meaning is preserved when the underlying value changes for a new feature or locale.

5. **Additive only.** Consistent with the IA-level design principle, each extension point is designed so that the v1.1 addition can be delivered by registering new tokens, new component variants, or new motion definitions — not by restructuring existing ones.

---

## Revision History

| Date | Author | Change |
|---|---|---|
| 2025-01-XX | UX/UI Designer | Initial draft — seven extension points identified from SRS section 12.3 and IA extension points |