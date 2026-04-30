# Hi-Fi Mockups — OneByTwo v1.0

> **Document owner:** UX/UI Designer
> **Status:** Draft
> **Design tokens source:** `docs/design/02-design-system/tokens.md`

---

## Overview

This directory contains eight self-contained HTML mockups for the hero screens
of OneByTwo v1.0. Each file uses inline CSS, no JavaScript frameworks, and no
external assets beyond Google Fonts (Inter). All design token values are taken
verbatim from the Phase 2 design system specification.

Every mockup renders correctly at iPhone 12 viewport (390x844) and a typical
Android viewport (412x892). Open any file directly in a browser to preview.

Hi-fi mockups are produced ONLY for these eight hero screens. Every other screen
is covered by wireframes (Phase 4, `docs/design/04-wireframes/`) and screen
specifications (Phase 6, `docs/design/06-screen-specs/`).

---

## Mockup Index

| # | File | Screen(s) | SRS Requirements | Wireframe Source |
|---|------|-----------|-----------------|------------------|
| 1 | `01-splash-and-onboarding.html` | Splash screen, onboarding slide | FR-AU-01 | `04-wireframes/auth-flow.md` |
| 2 | `02-phone-and-otp.html` | Phone entry (+91), OTP verification | FR-AU-01 through FR-AU-05 | `04-wireframes/auth-flow.md` |
| 3 | `03-home-dashboard.html` | Home dashboard (populated, light + dark) | FR-HD-01 through FR-HD-04 | `04-wireframes/home-dashboard.md` |
| 4 | `04-add-expense-bottom-sheet.html` | Add expense multi-step bottom sheet | FR-EX-01 through FR-EX-09 | `04-wireframes/expense-flow.md` |
| 5 | `05-group-detail.html` | Group detail with balances and expenses | FR-GR-01 through FR-GR-07, FR-SE-01 | `04-wireframes/groups-flow.md` |
| 6 | `06-settle-up.html` | Settle up with simplified-debts suggestion | FR-SE-01 through FR-SE-08 | `04-wireframes/settle-up-flow.md` |
| 7 | `07-activity-feed.html` | Activity feed with chronological events | FR-AC-01, FR-AC-02 | `04-wireframes/activity-feed.md` |
| 8 | `08-profile-with-support.html` | Profile screen with Contact Support | FR-PR-01 through FR-PR-05, FR-AU-08, FR-AU-09 | `04-wireframes/profile-and-support.md` |

---

## Design Token Compliance

All mockups use the following tokens from `docs/design/02-design-system/tokens.md`:

| Token | Light | Dark |
|-------|-------|------|
| Primary | #1F4E79 | #2E86AB |
| Secondary | #F4A261 | #F4A261 |
| Success (balance positive) | #2A9D8F | #2A9D8F |
| Danger (balance negative) | #E76F51 | #E76F51 |
| Surface | #FFFFFF | #1E1E1E |
| Background | #F8F9FA | #121212 |
| Text primary | #1A1A2E | #E0E0E0 |
| Typography | Inter 400/600/700 | Inter 400/600/700 |
| Corner radius (cards) | 16dp | 16dp |
| Corner radius (sheets) | 24dp | 24dp |

---

## Viewing Instructions

1. Open any `.html` file in a modern browser (Chrome, Safari, Firefox).
2. Use the browser's responsive design mode to preview at mobile viewport sizes.
3. For the home dashboard mockup (03), light and dark versions are shown side by
   side.

---

## Extension Points Marked

Several mockups include HTML comments marking v1.1 extension point slots:

- `06-settle-up.html`: `<!-- IA-EXT-01: UPI payment option slot -->`
- `08-profile-with-support.html`: `<!-- IA-EXT-03: Language selector row -->`
- `04-add-expense-bottom-sheet.html`: `<!-- IA-EXT-02: Recurring toggle slot -->`
