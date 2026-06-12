# Information Architecture — Extension Points

> **Document owner:** Product Manager
> **Version:** 1.0
> **Status:** Draft — pending Architect review
> **Audience:** Solution Architect, Flutter Dev, Product Manager

---

## Purpose

This document catalogues the named extension points in the v1.0 Information
Architecture where post-v1.0 features (SRS section 12.3) are intended to dock.
Each extension point identifies the exact screen, flow, or navigation path in
the current IA that will be affected, what exists today, what changes when the
feature ships, and — critically — what remains untouched. The goal is to ensure
the v1.0 IA is designed so that these future additions can be made without
restructuring existing navigation, state, or data flows.

All features referenced in the "v1.1 Feature" column are explicitly out of scope
for v1.0 (SRS section 12.3). No implementation work for these features shall
occur in v1.0 sprints. This table exists solely to inform architectural
decisions that preserve extensibility.

Note: the *What exists in v1.0* column states the v1.0 design target. As of this pass, the client has **not** yet built the Contact-Support mailto flow (IA-EXT-05 — currently a 'Coming soon' stub), the Universal/App-Link deep-link infra (IA-EXT-04 — only the in-app `NotificationDeepLinks` FCM resolver exists), or any Groups surface.

---

## Extension Points

| ID | Name | Location in v1.0 IA | v1.1 Feature | What exists in v1.0 | What changes when v1.1 lands | What stays untouched |
|---|---|---|---|---|---|---|
| IA-EXT-01 | Settle-up UPI slot | Core Screen 9: Settle Up flow (SRS section 6.3, item 9). Reached via "Settle Up" CTA on Friend detail, Group detail, or Home dashboard (FR-SE-07). | UPI deep-link integration (SRS section 12.3, bullet 1; docks into section 4.6 Settlements). | Absent. The Settle Up flow contains only the manual settlement recorder: amount (pre-filled from simplified-debts suggestion), date, optional note, and a "Record Settlement" action (FR-SE-05). No payment-method selector exists. | A payment-method selector appears below the manual recording option. Selecting "Pay via UPI" opens an OS-level UPI app picker (PhonePe, GPay, Paytm, etc.) via a UPI deep-link intent. On return, the app auto-records the settlement if a success callback is received. ADR-0015 (deep linking infrastructure) provides the routing foundation. | Manual settlement recording flow, simplified-debts computation (FR-SE-02 through FR-SE-04), settlement history (FR-SE-08), reminder flow (FR-SE-09), and the `simplifiedBalances` server-side projection are unchanged. |
| IA-EXT-02 | Recurring expense toggle | Core Screen 8: Add / Edit Expense bottom sheet (SRS section 6.3, item 8). Multi-step flow for amount, description, category, split method, and payer (FR-EX-01). | Recurring expenses and subscription splits (SRS section 12.3, bullet 3; docks into section 4.5 Expenses). | Absent. The expense creation flow captures a single occurrence only. There is no frequency selector, no recurrence rule, and no scheduled trigger. | A "Make this recurring" toggle appears after the date field. When enabled, it reveals a frequency picker (weekly, fortnightly, monthly, custom) and an optional end date. A Cloud Function scheduled trigger creates new expense documents on each recurrence date. | Expense data model fields for single-occurrence expenses (amount, description, category, split method, payer, notes, receipt — FR-EX-01 through FR-EX-09), the split-validation logic (FR-EX-04), the edit/delete flow (FR-EX-06), and the activity feed recording (FR-EX-07) are unchanged. |
| IA-EXT-03 | Language selector row | Core Screen 11: Profile and Settings (SRS section 6.3, item 11). Contains display name, profile photo, notification preferences, friend/group lists, and Contact Support (FR-PR-01 through FR-PR-05). | Hindi and other Indian-language localisations (SRS section 12.3, bullet 2; docks into section 5.9 Localisation). | Hidden. The v1.0 IA includes a "Language" settings row in the Profile screen's navigation tree, but it is not rendered. The `.arb` localisation infrastructure ships with `en` as the sole locale (ADR-0017). All user-facing strings are externalised; no hardcoded strings exist in widget code. | The "Language" row becomes visible, opening a locale picker listing supported languages (e.g., English, Hindi, Marathi, Tamil). Selecting a locale updates the app's `Locale`, loads the corresponding `.arb` file, and persists the preference. Date/time display remains IST regardless of language (SRS section 5.9). | Profile editing (FR-PR-01), phone number update (FR-PR-02), notification preferences (FR-PR-03), Contact Support (FR-PR-05), sign-out (FR-AU-08), and all other Profile screen functionality are unchanged. The `intl` infrastructure and `.arb` file structure are already in place and require no refactor. |
| IA-EXT-04 | Web companion deep-link target | Deep-link handler (ADR-0015). Invite links (FR-SH-02) and notification deep links (FR-AC-05) currently resolve via Universal Links (iOS) and App Links (Android) to the installed mobile app, with a fallback to the App Store or Play Store listing. | Web companion app (SRS section 12.3, bullet 4). | Mobile-only. The deep-link Cloud Function (or Firebase Hosting redirect per ADR-0015) routes exclusively to native app targets or store listings. There is no web application to fall back to. | The deep-link resolver gains a third routing branch: if the user is on a desktop or non-mobile browser, the link resolves to the web companion app instead of a store listing. The link schema defined in ADR-0015 remains identical; only the server-side routing logic changes. | The mobile deep-link flow — app-installed path, store-fallback path, notification deep links (FR-AC-05), invite link generation and expiry (FR-GR-03), and the system share sheet integration (FR-SH-01) — are unchanged. |
| IA-EXT-05 | Contact Support channel selector | Core Screen 11: Profile and Settings, specifically the "Contact Support" action (FR-PR-05, FR-SH-03). Reached via Profile screen. | Dedicated helpdesk integration — Freshdesk / Zoho Desk (SRS section 12.3, bullet 6). | Mailto only. The Contact Support action opens the device's default mail client via a `mailto:` URL pre-filled with the support address (from Remote Config), user ID, app version, OS, and device model (FR-SH-03). If no mail client is configured, a fallback dialog displays the support email with a "Copy" button (FR-SH-04). | The "Contact Support" action becomes a channel selector: "Email" (existing mailto flow) and "Chat with Support" (opens an embedded helpdesk widget or navigates to a helpdesk web view). The support address in Remote Config is extended with a helpdesk URL parameter. | The mailto flow (FR-SH-03), the no-mail-client fallback (FR-SH-04), the Remote Config lookup for the support address, the pre-filled triage metadata (user ID, app version, OS, device model), and all other Profile screen elements are unchanged. |
| IA-EXT-06 | Receipt OCR auto-fill | Core Screen 8: Add / Edit Expense bottom sheet (SRS section 6.3, item 8). Specifically, the receipt attachment step (FR-EX-05, P1) and the manual category selection (FR-EX-08). | AI-assisted receipt OCR and category prediction (SRS section 12.3, bullet 5). | Manual only. Users may optionally attach a receipt image (camera or gallery) to an expense (FR-EX-05). Category is selected manually from a predefined list of eight options (FR-EX-08). Amount, description, and date are entered by hand. The receipt image is stored in Firebase Storage but is not processed. | After a receipt image is attached, a "Scan receipt" action triggers a Cloud Function (or on-device ML model) that extracts amount, merchant name (mapped to description), date, and predicted category from the image. Extracted fields are presented as editable suggestions that the user confirms or overrides before saving. | The manual expense entry flow (FR-EX-01), the receipt attachment and storage mechanism (FR-EX-05), the predefined category list and icons (FR-EX-08), split-method selection (FR-EX-03), split validation (FR-EX-04), and currency formatting (FR-EX-09) are unchanged. Users who do not attach a receipt see no difference. |

---

## Cross-References

| Extension Point | SRS Sections | ADRs |
|---|---|---|
| IA-EXT-01 | 4.6, 6.3 (item 9), 12.3 (bullet 1) | ADR-0015 |
| IA-EXT-02 | 4.5, 6.3 (item 8), 12.3 (bullet 3) | — |
| IA-EXT-03 | 5.9, 6.3 (item 11), 12.3 (bullet 2) | ADR-0017 |
| IA-EXT-04 | 4.7 (FR-AC-05), 4.11 (FR-SH-02), 6.3, 12.3 (bullet 4) | ADR-0015 |
| IA-EXT-05 | 4.2 (FR-PR-05), 4.11 (FR-SH-03, FR-SH-04), 6.3 (item 11), 12.3 (bullet 6) | — |
| IA-EXT-06 | 4.5 (FR-EX-05, FR-EX-08), 6.3 (item 8), 12.3 (bullet 5) | — |

---

## Design Principles for Extension Points

1. **Slot, not stub.** Extension points are conceptual slots in the IA — places
   where future navigation nodes, UI elements, or flow branches will appear.
   They are not implemented as hidden widgets, feature flags, or dead code in
   v1.0. The v1.0 codebase contains no artefacts for these features beyond the
   structural prerequisites already mandated by the SRS (e.g., externalised
   strings for IA-EXT-03, deep-link infrastructure for IA-EXT-04).

2. **Additive only.** Each extension point is designed so that the v1.1 feature
   can be delivered by *adding* new screens, widgets, providers, or Cloud
   Functions — not by restructuring existing ones. The "What stays untouched"
   column is a contractual guarantee to the development team.

3. **One extension, one concern.** Each extension point maps to exactly one
   out-of-scope feature from SRS section 12.3. If a future feature requires
   multiple IA changes, each change gets its own extension point ID.

---

## Revision History

| Date | Author | Change |
|---|---|---|
| 2025-01-XX | Product Manager | Initial draft — six extension points identified from SRS section 12.3 |
