# Extension Points — Master Register

> **Document owner:** Solution Architect
> **Version:** 1.0
> **Status:** Draft — pending cross-team review
> **Audience:** Solution Architect, Flutter Developer, Cloud Functions Developer, UX/UI Designer, Product Manager

---

## Purpose

Consolidated register of every v1.1 extension point across all design phases. This document serves as the single reference for understanding where future features will dock into the v1.0 system. Each row identifies a named seam — a screen, component, schema field, or backend module — that v1.0 ships with a minimal or default implementation and that v1.1 will extend additively.

All features referenced below are explicitly out of scope for v1.0 (SRS section 12.3). No implementation work for these features shall occur in v1.0 sprints. This register exists solely to ensure traceability across design phases and to prevent architectural decisions in one phase from contradicting extension commitments made in another.

Extension points are drawn from three design phases:

- **Phase 1 — Information Architecture** (`docs/design/01-information-architecture/extension-points.md`): navigation, flows, and screen structure.
- **Phase 2 — Design System** (`docs/design/02-design-system/extension-points.md`): visual tokens, component variants, and interaction patterns.
- **Phase 3 — Architecture** (`docs/design/03-architecture/extension-points.md`): Firestore schema fields, Cloud Function modules, and backend contracts.

---

## Register Table

| ID | Name | Phase | Location (file / component / field) | What v1.0 provides | What v1.1 changes | v1.1 Feature unlocked |
|---|---|---|---|---|---|---|
| IA-EXT-01 | Settle-up UPI slot | Information Architecture | Core Screen 9: Settle Up flow (SRS section 6.3, item 9) | Manual settlement recorder only — amount, date, optional note, and "Record Settlement" action. No payment-method selector exists. | A payment-method selector appears below the manual recording option. Selecting "Pay via UPI" opens an OS-level UPI app picker via a deep-link intent; on return, the app auto-records the settlement if a success callback is received. | UPI deep-link payments |
| IA-EXT-02 | Recurring expense toggle | Information Architecture | Core Screen 8: Add / Edit Expense bottom sheet (SRS section 6.3, item 8) | Expense creation flow captures a single occurrence only. No frequency selector, recurrence rule, or scheduled trigger. | A "Make this recurring" toggle appears after the date field, revealing a frequency picker (weekly, fortnightly, monthly, custom) and an optional end date. A Cloud Function creates new expense documents on each recurrence date. | Recurring expenses |
| IA-EXT-03 | Language selector row | Information Architecture | Core Screen 11: Profile and Settings (SRS section 6.3, item 11) | Hidden "Language" settings row; `.arb` infrastructure ships with `en` as the sole locale (ADR-0017). All strings externalised. | The "Language" row becomes visible, opening a locale picker. Selecting a locale updates the app's `Locale`, loads the corresponding `.arb` file, and persists the preference. | Hindi / multi-language |
| IA-EXT-04 | Web companion deep-link target | Deep-link handler (ADR-0015) | Deep-link Cloud Function or Firebase Hosting redirect routes exclusively to native app targets or store listings. No web application exists. | The deep-link resolver gains a third routing branch: desktop or non-mobile browsers resolve to the web companion app instead of a store listing. Link schema unchanged; only server-side routing logic changes. | Web companion |
| IA-EXT-05 | Contact Support channel selector | Information Architecture | Core Screen 11: Profile and Settings, "Contact Support" action (FR-PR-05, FR-SH-03) | `mailto:` URL pre-filled with support address, user ID, app version, OS, and device model. Fallback dialog if no mail client configured. | "Contact Support" becomes a channel selector: "Email" (existing mailto flow) and "Chat with Support" (embedded helpdesk widget or web view). | Helpdesk integration |
| IA-EXT-06 | Receipt OCR auto-fill | Information Architecture | Core Screen 8: Add / Edit Expense bottom sheet, receipt attachment step (FR-EX-05) and category selection (FR-EX-08) | Optional receipt image attachment (camera or gallery). Category selected manually from eight predefined options. Receipt image stored but not processed. | After a receipt is attached, a "Scan receipt" action triggers extraction of amount, merchant name, date, and predicted category. Extracted fields presented as editable suggestions the user confirms or overrides. | AI receipt OCR |
| DS-EXT-01 | Hindi font fallback stack | Design System | Typography token (`fontFamily.body`, `fontFamily.heading`) | Inter or Plus Jakarta Sans for Latin glyphs with platform system font fallback. Line-height minimum 1.4x for body text. | Noto Sans Devanagari (or equivalent) inserted into font fallback stack after the Latin primary face. Font weights match Latin face (400, 500, 600, 700). Additional Indic script faces may follow. | Hindi / multi-language |
| DS-EXT-02 | RecurrenceChip component | Design System | Chip component (`ChipVariant` enumeration) | Base `Chip` widget for category labels and split-method indicators. Variants mapped to Primary, Secondary, Success, Danger. | `RecurrenceChip` variant displaying frequency labels ("Monthly", "Weekly", etc.) with a new informational semantic colour and an optional trailing recurrence icon. | Recurring expenses |
| DS-EXT-03 | UpiAppLogoRow component | Design System | Settle Up flow component; asset directory `assets/logos/` | Icon system uses a single icon font or SVG asset set containing only first-party glyphs. No payment-method selector or third-party branding. | Horizontal row of tappable UPI app logos (GPay, PhonePe, Paytm) as a payment-method selector. Logo dimensions governed by `iconSize.appLogo` token (40x40 dp, 48x48 dp tap target). | UPI deep-link payments |
| DS-EXT-04 | Multi-currency token slot | Design System | Currency formatter utility in `lib/core/` | All amounts formatted as INR with Indian numbering system, two decimal places, and `₹` prefix. | Currency-aware formatting: symbol, decimal separator, thousands grouping, and precision determined by currency code. `MoneyText` widget accepts a currency code parameter defaulting to `INR`. | Multi-currency |
| DS-EXT-05 | RTL layout support | Design System | All layout files — `EdgeInsetsDirectional`, `MainAxisAlignment`, directional icon tokens | English-only, left-to-right layout. All screens designed and tested in LTR. | Support for RTL scripts (Urdu, potentially Arabic). Layouts mirror: leading/trailing edges swap, text alignment flips, directional icons reverse, swipe gestures invert. | Hindi / multi-language |
| DS-EXT-06 | AI Suggestion Card | Design System | Card component (`suggested` state); motion token namespace | Card component supports standard states (default, selected, disabled, error). All expense fields are user-authored; no auto-population. | New `suggested` card state with per-field confidence indicators (high/medium/low), inline "Edit" affordances, and a shimmer/pulse motion token (1000-1500 ms, looping). New `Suggested` semantic colour token. | AI receipt OCR |
| DS-EXT-07 | Helpdesk chat affordance | Design System | Settings list-tile component; badge and status-dot sub-components | "Contact Support" styled as a standard list tile with leading icon and trailing chevron. | List tile supports expansion into a channel selector. Badge slot for unread counts. `StatusDot` sub-component (online/offline) in trailing slot. Trailing chevron becomes a semantic icon token (`icon.expand` / `icon.navigate`). | Helpdesk integration |
| ARCH-EXT-01 | Settlement method discriminator | Architecture | `settlements/{settlementId}`, field `method` | Always `'manual'`. Written on every settlement document at creation time. | Adds `'upi'` as a second permitted value. When `method` is `'upi'`, additional fields `upiTransactionId` and `upiApp` are present. Security rules validate `upiTransactionId` is non-empty when `method` is `'upi'`. | UPI deep-link payments |
| ARCH-EXT-02 | Currency field on expenses and settlements | Architecture | `expenses` and `settlements` collections, field `currency` | Always `'INR'`. Written on every expense and settlement document at creation time. | Supports additional ISO 4217 currency codes. `amountPaise` reinterpreted as smallest unit of specified currency. Simplified-debts algorithm operates per-currency. | Multi-currency |
| ARCH-EXT-03 | Recurring rule sub-document on expenses | Architecture | `expenses` collections, optional field `recurringRule` | **Omitted by the client** — `ExpenseDoc` does not write the field — and the security rules accept it absent **or** `null` (`!('recurringRule' in data) || data.recurringRule == null`). This is the one extension field that is *not* written at creation time. | When non-null, contains `{ frequency, interval, endDate, nextOccurrence }`. A scheduled Cloud Function creates new expense documents on recurrence and advances `nextOccurrence`. | Recurring expenses |
| ARCH-EXT-04 | Locale field on user documents | Architecture | `users/{userId}`, field `locale` | Always `'en-IN'`. Written on every user document at creation time. | Supports additional BCP 47 locale codes (`'hi-IN'`, `'mr-IN'`, `'ta-IN'`). Drives `.arb` file loading, notification body language, and date/number formatting. | Hindi / multi-language |
| ARCH-EXT-05 | Notification channel expansion | Architecture | Cloud Functions notification module (`functions/src/notifications/`) | FCM push notifications only. The module exposes a **function-based** `NotificationsApi` (`sendExpenseNotification`, `sendSettlementNotification`, `sendReminderNotification`) over an FCM transport (`fcm-send.ts`), with shared `payload-renderer.ts` and `prefs-filter.ts`. There is **no** `NotificationChannel`/`FcmChannel` strategy class today. | Additional channel implementations: `SmsChannel`, `EmailChannel`, `InAppInboxChannel`. Channel selector reads user preferences from `notificationPrefs` sub-document. | Notification channels |
| ARCH-EXT-06 | Settlement verification status | Architecture | `settlements/{settlementId}`, field `verificationStatus` | Always `'unverified'`. Written on every settlement document at creation time. Client-read-only (Cloud Functions only may write). | Adds `'verified'`, `'pending'`, and `'failed'` states. UPI settlements start as `'pending'`; a Cloud Function webhook transitions to `'verified'` or `'failed'`. Failed settlements excluded from balance computations. | UPI deep-link payments |
| ARCH-EXT-07 | Expense source discriminator | Architecture | `expenses` collections, field `source` | Always `'manual'`. Written on every expense document at creation time. | Adds `'ocr'` as a second permitted value. When `source` is `'ocr'`, additional metadata fields `ocrConfidence` and `ocrExtractedFields` may be present. Future values could include `'import'`. | AI receipt OCR |

---

## Grouped by v1.1 Feature

### 1. UPI deep-link payments

Seams that collectively enable settle-via-UPI functionality across the Settle Up flow.

| ID | Phase | Seam summary |
|---|---|---|
| IA-EXT-01 | Information Architecture | Payment-method selector slot in the Settle Up flow |
| ARCH-EXT-01 | Architecture | `method` discriminator field on settlement documents (`'manual'` / `'upi'`) |
| ARCH-EXT-06 | Architecture | `verificationStatus` field on settlement documents (`'unverified'` / `'pending'` / `'verified'` / `'failed'`) |
| DS-EXT-03 | Design System | `UpiAppLogoRow` component and third-party logo asset pipeline |

**Activation sequence:** ARCH-EXT-01 and ARCH-EXT-06 provide the schema foundation. IA-EXT-01 defines the navigation slot. DS-EXT-03 supplies the visual component. All four seams must be activated together; partial activation would create an inconsistent user experience.

---

### 2. Hindi / multi-language

Seams that collectively enable Indian-language localisations and potential RTL script support.

| ID | Phase | Seam summary |
|---|---|---|
| IA-EXT-03 | Information Architecture | Language selector row in Profile and Settings |
| ARCH-EXT-04 | Architecture | `locale` field on user documents (`'en-IN'` default) |
| DS-EXT-01 | Design System | Hindi (Devanagari) font fallback stack in typography tokens |
| DS-EXT-05 | Design System | RTL layout support via logical directional properties |

**Activation sequence:** ARCH-EXT-04 provides the persisted locale preference. IA-EXT-03 exposes the selection UI. DS-EXT-01 ensures correct glyph rendering. DS-EXT-05 ensures layout integrity for RTL scripts. DS-EXT-01 can ship independently of DS-EXT-05 (Hindi is LTR), but DS-EXT-05 is required before any RTL locale is supported.

---

### 3. Recurring expenses

Seams that collectively enable recurring expense creation and automated recurrence.

| ID | Phase | Seam summary |
|---|---|---|
| IA-EXT-02 | Information Architecture | "Make this recurring" toggle in the Add / Edit Expense flow |
| ARCH-EXT-03 | Architecture | `recurringRule` optional sub-document on expense documents |
| DS-EXT-02 | Design System | `RecurrenceChip` component variant with informational colour token |

**Activation sequence:** ARCH-EXT-03 provides the schema foundation. IA-EXT-02 defines the user-facing toggle. DS-EXT-02 supplies the visual indicator on expense lists. A scheduled Cloud Function (not an extension point itself, but dependent on ARCH-EXT-03) drives the automated creation of recurring expense instances.

---

### 4. Web companion

Seams that enable a browser-based companion application reachable via existing deep links.

| ID | Phase | Seam summary |
|---|---|---|
| IA-EXT-04 | Information Architecture | Third routing branch in the deep-link resolver for desktop/non-mobile browsers |

**Activation sequence:** Single seam. The deep-link schema (ADR-0015) is unchanged; only the server-side routing logic requires modification. No schema or design-system changes are needed.

---

### 5. Helpdesk integration

Seams that enable embedded helpdesk chat alongside the existing email support flow.

| ID | Phase | Seam summary |
|---|---|---|
| IA-EXT-05 | Information Architecture | Channel selector replacing the single "Contact Support" action |
| DS-EXT-07 | Design System | Expandable list tile with badge slot and `StatusDot` sub-component |

**Activation sequence:** IA-EXT-05 defines the interaction model. DS-EXT-07 supplies the visual components (badge, status dot, expandable tile). The helpdesk provider SDK (Freshdesk / Zoho Desk) is integrated at activation time; no v1.0 dependency on any helpdesk vendor.

---

### 6. AI receipt OCR

Seams that collectively enable AI-assisted receipt scanning with editable field suggestions.

| ID | Phase | Seam summary |
|---|---|---|
| IA-EXT-06 | Information Architecture | "Scan receipt" action and editable suggestion overlay in the Add / Edit Expense flow |
| ARCH-EXT-07 | Architecture | `source` discriminator field on expense documents (`'manual'` / `'ocr'`) with optional OCR metadata |
| DS-EXT-06 | Design System | `AI Suggestion Card` component with `suggested` state, confidence indicators, and shimmer motion token |

**Activation sequence:** ARCH-EXT-07 provides the schema foundation. IA-EXT-06 defines the user flow. DS-EXT-06 supplies the visual treatment for machine-suggested fields. The OCR processing backend (Cloud Function or on-device ML model) is implemented at activation time.

---

### 7. Multi-currency

Seams that enable support for currencies beyond INR.

| ID | Phase | Seam summary |
|---|---|---|
| ARCH-EXT-02 | Architecture | `currency` field on expense and settlement documents (`'INR'` default) |
| DS-EXT-04 | Design System | Currency-aware formatting tokens and parameterised `MoneyText` widget |

**Activation sequence:** ARCH-EXT-02 provides the schema foundation. DS-EXT-04 ensures the UI can render non-INR amounts with correct symbols and grouping patterns. The simplified-debts algorithm (SRS section 7.4) requires extension to operate per-currency within multi-currency groups.

---

### 8. Notification channels

Seams that enable notification delivery beyond FCM push notifications.

| ID | Phase | Seam summary |
|---|---|---|
| ARCH-EXT-05 | Architecture | Function-based `NotificationsApi` notification module that a future strategy/dispatcher will extend with pluggable channels |

**Activation sequence:** Single seam. The v1.0 notification module
(`functions/src/notifications/`) is **function-based** — `NotificationsApi` over an FCM
transport (`fcm-send.ts`) with shared `payload-renderer.ts` and `prefs-filter.ts`; it is
**not** a class-based strategy pattern yet. Adding a new channel (SMS, email, in-app
inbox) would mean introducing a channel abstraction plus a dispatcher and routing
through `prefs-filter.ts`. No schema or IA changes are needed; user preference controls
in the Profile screen are the only client-side addition.

---

## Summary Statistics

| Metric | Count |
|---|---|
| Total extension points | 20 |
| Information Architecture (IA-EXT) | 6 |
| Design System (DS-EXT) | 7 |
| Architecture (ARCH-EXT) | 7 |
| Distinct v1.1 features unlocked | 8 |
| Schema fields requiring v1.0 default values | 7 (see Architecture extension points, Schema Field Summary) |

---

## Cross-References

| Source document | Path |
|---|---|
| IA extension points | `docs/design/01-information-architecture/extension-points.md` |
| DS extension points | `docs/design/02-design-system/extension-points.md` |
| Architecture extension points | `docs/design/03-architecture/extension-points.md` |
| Out-of-scope features | SRS section 12.3 |
| Deep-link infrastructure | ADR-0015 |
| Localisation infrastructure | ADR-0017 |

---

## Revision History

| Date | Author | Change |
|---|---|---|
| 2025-01-XX | Solution Architect | Initial draft — consolidated 20 extension points from IA, DS, and Architecture phases |
