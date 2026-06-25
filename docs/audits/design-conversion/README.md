# Design Conversion Sprint — Planning Pack (new Sprint 3)

**Status:** Planning (this session). **No application code is reskinned here.**
**Author:** Orchestrator, with the agent team (designer, pm, architect, qa, devops, flutter-dev).
**Date:** 2026-06-25

This pack plans the **Design Conversion Sprint** that migrates the already-built app and
every upcoming feature onto the new high-fidelity visual system, **"Direction A — Haldi"**,
delivered at `design_handoff_one_by_two/`. The new sprint is inserted as **Sprint 3**; every
currently-numbered sprint shifts forward by one.

---

## Phase 0 — Framing (read first; binding for every artefact in this pack)

1. **This is planning, not conversion.** No `lib/**` reskin, no screen conversion, no
   `theme.dart` edit in this session. The first conversion PR ("Sprint 3 PR #1 — design-token
   foundation") is the *next* session.
2. **`design_handoff_one_by_two/` is the authoritative visual system.** It supersedes the OLD
   **visual-layer** docs only:
   - `docs/design/02-design-system/{tokens,components,typography-and-formatting,motion-and-interaction}.md`
   - `docs/design/04-wireframes/*`, `docs/design/05-mockups/*`, `docs/design/06-screen-specs/*`
   These remain in the repo as historical references; the Haldi handoff is now canonical.
3. **The backend/data layer is UNCHANGED.** Do **not** re-plan
   `docs/design/03-architecture/*` or `docs/design/07-technical/{firestore-schema,firestore-security-rules,cloud-functions-catalogue}.md`.
   The data model, security rules, simplified-debts algorithm, Cloud Functions, and all
   backend contracts are authoritative as-is. This redesign is **visual/UX only**.
4. **The four invariants are untouched and re-affirmed by the Haldi handoff.** Any plan item
   that appears to weaken one is a blocking defect — refuse and cite the invariant.
5. **Output shape:** a planning-doc set under `docs/audits/design-conversion/` and
   `docs/sprint-zero/`, the renumbered roadmap, an ADR, an `update-srs` proposal, and a thin
   docs PR carrying the renumbered roadmap + the GitHub milestone reconciliation.

---

## The four invariants (re-affirmed by Haldi — never weaken)

1. **Money is integer paise.** Rupee conversion happens only at the UI layer via
   `formatInrFromPaise()` (`lib/core/formatters/inr_formatter.dart`). The Haldi README restates
   this: *"Store integer paise internally; only the rupee display is designed."* No floats for money.
2. **`simplifiedBalances` is server-written / client-read-only.** Haldi restates *"Simplified
   debts only: settle-up always shows ONE pre-filled suggested payment … Never render a raw
   who-paid-whom debt graph."* The UI reads the projection; it never writes it.
3. **OS system share sheet only.** Haldi restates *"invites hand off to the OS system share
   sheet only. No WhatsApp/SMS/any-single-app buttons."*
4. **Single Firebase project.** All pre-merge testing runs against the Firebase Emulator Suite.

### Three disabled "extension slots" (present but inert; tagged "Coming soon" — do NOT build live)
- Settle Up → "Pay via UPI" row.
- Add Expense (Step 3) → "Make recurring" toggle.
- Profile → Notifications → "Language" row.

---

## Canonical vocabulary

### The 30 Haldi screens (authoritative numbering from `design_handoff_one_by_two/README.md`)

| № | Screen | Hero (L+D)? |
|---|---|---|
| 1 | Splash | yes |
| 2 | Onboarding (3 slides) | |
| 3 | Phone entry (+91 locked) | |
| 4 | OTP (6-box) | |
| 5 | Profile setup | |
| 6 | Home dashboard | ★ |
| 7 | Search | |
| 8 | Add-expense context picker | |
| 9 | Friends list | ★ |
| 10 | Add friend (lookup branches) | |
| 11 | Friend detail | |
| 12 | Friend history | |
| 13 | Remove friend | |
| 14 | Groups list | |
| 15 | Create group | |
| 16 | Group detail (Expenses/Balances/Activity) | ★ |
| 17 | Invite members | |
| 18 | Group members | |
| 19 | Leave / delete group | |
| 20 | Group history | |
| 21 | Add expense — 3-step bottom sheet | ★ |
| 22 | View expense (detail) + edit/delete | |
| 23 | Settle up | ★ |
| 24 | Settlement history (+ reminder compose) | |
| 25 | Activity feed | ★ |
| 26 | Push notifications | |
| 27 | Profile view + edit | |
| 28 | Notification preferences | |
| 29 | Contact support | |
| 30 | Delete account | |
| Phase3g | Change Phone (FR-PR-02 re-verification — added 2026-06-25) | |

> Note: the **Change Phone** flow (Phase3g) was added to the handoff on 2026-06-25, after the
> initial 30 screens, resolving the one coverage gap (FR-PR-02). See `01-coverage-gap.md`.

Plus **global overlays** (design once, reuse): add-expense sheet, settle-up sheet, delete
confirmations, sign-out confirmation, offline banner, snackbars/toasts.

### Built app surface (current — to be converted in later sessions)

Screens (19 `*screen*.dart`) under `lib/features/*/presentation/`:
- **auth/** `splash_screen`, `phone_entry_screen`, `otp_entry_screen`, `profile_setup_screen`, `authenticated_screen`
- **home/** `home_dashboard_screen`
- **friends/** `friends_list_screen`, `add_friend_screen`, `match_and_invite_screen`, `friend_detail_screen`
- **expenses/** `expense_detail_screen` (+ `widgets/receipt_fullscreen_viewer.dart`)
- **settlements/** `settlement_history_screen`
- **activity/** `activity_feed_screen`
- **profile/** `profile_screen`, `edit_profile_screen`, `change_phone_screen`, `notification_preferences_screen`, `delete_account_screen`, `profile_placeholder_screen`
- **groups/** — empty stub (Groups UI NOT built; arrives in the new Sprint 4)
- **reminders/**, **notifications/**, **shell/** — supporting surfaces (enumerate during Phase 2)

Shared widgets under `lib/core/widgets/`: `OBTBottomNav` (`nav/`), `OBTFloatingActionButton`
(`nav/`), `OBTAmountInput` (`inputs/`), `OBTActivityRow` (`lists/`), `OBTConfirmationDialog`
(`dialogs/`), `india_phone_input_formatter.dart`. Plus `OBTSettleUpCard` (in `lib/features/friends/...`).
Tokens + type live in `lib/app/theme.dart` (`AppTheme.light`/`.dark`, Material 3).

### Haldi tokens (summary — full set in `design_handoff_one_by_two/README.md`)
- `primary #E0922E` (dark `#EAA24A`); **`onPrimary #2A211B` ink, NOT white** (AA on marigold = 5.6:1).
- `background #FBF6EE`/`#1A1510`, `surface #FFFFFF`/`#241D16`, `surfaceVariant #FFF6E6`/`#2E2620`.
- Balance trio (colour + icon + label, never colour alone): positive `#0F7D6B` + `arrow_upward`;
  negative `#BC4030` + `arrow_downward`; zero `#6F6557` + `check`.
- 8-hue colour-blind-safe category palette (chips at ~10% opacity).
- Type: **Bricolage Grotesque** (display/headings, tabular figures for amounts) + **Hanken
  Grotesk** (text/UI), via `google_fonts`.
- Radii pills/cards/sheets 16–28; soft warm shadows (no hard borders); motion 200–300ms with
  reduced-motion fallback. Verified AA/AAA pairings are listed in the Haldi README.

### Renumber mapping (this pack)

| New № | Theme | Was |
|---|---|---|
| **Sprint 3** | **Design Conversion (Haldi)** | — (new) |
| Sprint 4 | Groups and Settlements (FR-GR-01..07, FR-SE-05..08) | Sprint 3 |
| Sprint 5 | Notifications, Activity, Dashboard | Sprint 4 |
| Sprint 6 | Polish, Support, Offline, Search | Sprint 5 |
| Sprint 7 | QA, Performance, Release Prep (v1.0 RC) | Sprint 6 |

`Post-v1.0` is unchanged. ADR for the adoption = **ADR-0024**.

---

## Index of this pack

| File | Phase | Author |
|---|---|---|
| `01-coverage-gap.md` | 1 — Design-coverage gap analysis (30 Haldi screens × app/FRs; missing-design list) | Designer |
| `02-conversion-checklist.md` | 2 — Implementation-conformance (per screen + per component: conform/reskin/rebuild) | Flutter Dev + Designer |
| `03-foundation-plan.md` | 3 — Token + type + component foundation plan | Architect + Designer |
| `04-qa-test-strategy.md` | 7 — Golden/contrast/dynamic-type verification strategy | QA |
| `../../sprint-zero/sprint-3-plan.md` | 5 — Sprint 3 (Design Conversion) plan | PM |
| `../../sprint-zero/srs-update-proposal-haldi.md` | update-srs — SRS §6.2/§6.3 proposal | PM |
| `.github/shared/decision-log.md` (ADR-0024) | 3 — adoption decision | Architect |

> **Next: Sprint 3 PR #1 — design-token foundation (`lib/app/theme.dart` → Haldi tokens + Bricolage/Hanken).**
