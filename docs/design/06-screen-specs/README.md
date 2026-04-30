# Screen Specifications — One By Two v1.0

> **Document owner:** UX/UI Designer, PM, QA
> **Status:** Draft
> **Total screens specified:** 28

---

## Overview

This directory contains detailed screen-level specifications for every screen in
One By Two v1.0. Each specification includes: purpose, route, SRS requirements,
navigation context, components used, all states (default, loading, empty, error,
populated, offline), inputs with validation rules and exact error messages,
telemetry events, accessibility semantics, QA-identified edge cases, and open
questions for the architect.

Screens are grouped by flow area in six files.

---

## Index

| File | Screens | SRS Coverage |
|------|---------|--------------|
| `01-05-auth-and-profile-setup.md` | SCR-01 Splash, SCR-02 Onboarding, SCR-03 Phone Entry, SCR-04 OTP Verification, SCR-05 Profile Setup | FR-AU-01 to FR-AU-08 |
| `06-08-home-and-search.md` | SCR-06 Home Dashboard, SCR-07 Search Overlay, SCR-08 Add Expense Entry | FR-HD-01 to FR-HD-04, FR-SR-01, FR-SR-02 |
| `09-12-friends.md` | SCR-09 Friends List, SCR-10 Add Friend, SCR-11 Friend Detail, SCR-12 Delete Friend | FR-FR-01 to FR-FR-05, FR-SH-01 |
| `13-18-groups.md` | SCR-13 Groups List, SCR-14 Create Group, SCR-15 Group Detail, SCR-16 Invite Members, SCR-17 Group Members, SCR-18 Delete/Leave Group | FR-GR-01 to FR-GR-07, FR-SH-01 |
| `19-22-expenses.md` | SCR-19 Add Expense (Amount), SCR-20 Add Expense (Split), SCR-21 Add Expense (Receipt/Confirm), SCR-22 Edit/Delete Expense | FR-EX-01 to FR-EX-09 |
| `23-28-settle-activity-profile.md` | SCR-23 Settle Up, SCR-24 Settlement History, SCR-25 Activity Feed, SCR-26 Profile, SCR-27 Notification Prefs, SCR-28 Support/Deletion | FR-SE-05 to FR-SE-08, FR-AC-01, FR-AC-02, FR-PR-01 to FR-PR-05, FR-SH-03, FR-SH-04, FR-AU-08, FR-AU-09 |

---

## Cross-References

- **Wireframes:** `docs/design/04-wireframes/` — lo-fi layouts for each flow
- **Hi-fi mockups:** `docs/design/05-mockups/` — 8 hero screen HTML mockups
- **Component catalogue:** `docs/design/02-design-system/components.md`
- **Design tokens:** `docs/design/02-design-system/tokens.md`
- **Site map:** `docs/design/01-information-architecture/site-map.md`
