# 01 — Design-coverage gap analysis (Phase 1)

**Pack:** Design Conversion Sprint (new Sprint 3) — Planning.
**Author:** Designer. **Date:** 2026-06-25. **Status:** Planning — no `lib/**` code is touched.
**Reads:** `docs/audits/design-conversion/README.md` (canonical framing, numbering, invariants),
`design_handoff_one_by_two/README.md` (the Haldi spec), SRS §6.1–6.3.

---

## A. Scope and method

This document maps the **30 "Direction A — Haldi" screens** against (a) the app's
currently-built screens under `lib/features/*/presentation/` and (b) the SRS functional
requirements (`docs/OneByTwo_Requirements_Spec.md` §6/§7). Its purpose is to find every
gap **before** any screen is reskinned, so the Sprint 3 conversion plan knows which
surfaces have a Haldi target to convert *to*, which need a design commissioned first,
and which are throwaway.

This is **visual/UX planning only**. The backend and data layer are unchanged: the
Firestore schema, security rules, the simplified-debts Cloud Function, the
`simplifiedBalances` projection, and all backend contracts are authoritative as-is and
are **not** re-planned here. The four invariants (§E) are re-affirmed, not weakened.

Method: every `*_screen.dart` / sheet / dialog under `lib/features/*/presentation/` was
opened and its top-of-file doc comment read to identify the FR / SCR it implements; the FR
catalogue (SRS §7, lines 160–273) was cross-referenced; `lib/features/groups/` was
confirmed to contain no Dart files. No file was modified.

**Numbering:** Haldi screen numbers are the authoritative 1–30 from the canonical README.
"FR-" ids and "SCR-" ids are the SRS / built-app identifiers carried in each screen's doc
comment. Where a Haldi screen has no built equivalent the `app screen / FR` cell shows the
governing FR only.

---

## B. Coverage matrix (30 Haldi screens)

Status values: **covered** (a matching built screen exists) · **designed-not-yet-built**
(Haldi designs it; the app screen is not built) · **mismatch** (built screen and Haldi
screen diverge in scope/behaviour). A fourth value, **built-not-yet-designed** (a built
surface the 30-screen handoff does not cover), cannot apply to a Haldi-screen row by
definition; those surfaces are captured in the addendum table below the main matrix and in §C.

| Haldi screen № | app screen / FR | status |
|---|---|---|
| 1 — Splash | `auth/presentation/splash_screen.dart` (SCR-01) | covered |
| 2 — Onboarding (3 slides) | *(no built screen)* — SRS §6.3 #1 | designed-not-yet-built |
| 3 — Phone entry (+91 locked) | `auth/presentation/phone_entry_screen.dart` (FR-AU-01, FR-AU-02) | covered |
| 4 — OTP (6-box) | `auth/presentation/otp_entry_screen.dart` (FR-AU-03, FR-AU-04, FR-AU-05) | covered |
| 5 — Profile setup | `auth/presentation/profile_setup_screen.dart` (FR-AU-06) | covered |
| 6 — Home dashboard | `home/presentation/home_dashboard_screen.dart` (FR-HD-01..04) | covered |
| 7 — Search | *(not built)* — polish sprint, no FR id | designed-not-yet-built |
| 8 — Add-expense context picker | `shell/presentation/add_expense_context_picker_sheet.dart` (SCR-08, FR-HD-04) | covered ¹ |
| 9 — Friends list | `friends/presentation/friends_list_screen.dart` (FR-FR-03) | covered |
| 10 — Add friend (lookup branches) | `friends/presentation/add_friend_screen.dart` + `add_friend_flow.dart` + `match_and_invite_screen.dart` (FR-FR-01, FR-FR-02) | covered |
| 11 — Friend detail | `friends/presentation/friend_detail_screen.dart` (FR-FR-04) | covered |
| 12 — Friend history | `friends/presentation/friend_detail_screen.dart` (top-5 inline only) — FR-FR-04 | designed-not-yet-built ² |
| 13 — Remove friend | *(no presentation UI; removal logic only in `friends/data/friendship_repository.dart`)* — FR-FR-05 | designed-not-yet-built |
| 14 — Groups list | `shell/presentation/groups_list_placeholder.dart` (placeholder only) — FR-GR-04 | designed-not-yet-built |
| 15 — Create group | *(not built)* — FR-GR-01 | designed-not-yet-built |
| 16 — Group detail (Expenses/Balances/Activity) | *(not built)* — FR-GR-04 | designed-not-yet-built |
| 17 — Invite members | *(not built)* — FR-GR-02, FR-GR-03 | designed-not-yet-built |
| 18 — Group members | *(not built)* — FR-GR-05 | designed-not-yet-built |
| 19 — Leave / delete group | *(not built)* — FR-GR-06, FR-GR-07 | designed-not-yet-built |
| 20 — Group history | *(not built)* — FR-GR-04 | designed-not-yet-built |
| 21 — Add expense — 3-step bottom sheet | `expenses/presentation/add_expense_bottom_sheet.dart` + `steps/step_1..3` (FR-EX-01..08) | covered |
| 22 — View expense + edit/delete | `expenses/presentation/expense_detail_screen.dart` (SCR-22, FR-EX-06) | covered |
| 23 — Settle up | `settlements/presentation/settle_up_bottom_sheet.dart` (SCR-23, FR-SE-05) | covered |
| 24 — Settlement history (+ reminder compose) | `settlements/presentation/settlement_history_screen.dart` (SCR-24, FR-SE-08); reminder via `reminders/` + Friend detail (FR-SE-09) | covered ³ |
| 25 — Activity feed | `activity/presentation/activity_feed_screen.dart` (SCR-25, FR-AC-01, FR-AC-02) | covered |
| 26 — Push notifications | `notifications/presentation/notifications_lifecycle_host.dart` + `widgets/in_app_notification_banner.dart` + `pre_permission_dialog.dart` (FR-AC-03, FR-AC-05) | covered ⁴ |
| 27 — Profile view + edit | `profile/presentation/profile_screen.dart` + `edit_profile_screen.dart` (FR-PR-01) | covered |
| 28 — Notification preferences | `profile/presentation/notification_preferences_screen.dart` (FR-PR-03) | covered |
| 29 — Contact support | `profile/presentation/contact_support_fallback_dialog.dart` + `contact_support_controller` (FR-SH-03, FR-SH-04, FR-PR-05) | covered |
| 30 — Delete account | `profile/presentation/delete_account_screen.dart` (FR-AU-09, SCR-28) | covered |

**Row notes**

1. **Haldi 8 (covered, partial).** The picker is built with the Friends section live; the
   Groups section is an intentional "Coming soon" stub row that lights up only when the
   Groups epic ships (the in-code "Sprint 3" label predates the renumber → now **Sprint 4**).
   No new design needed; the Groups branch reuses Haldi 14/16 when those are built.
2. **Haldi 12 (designed-not-yet-built).** FR-FR-04's full reverse-chron per-friend log is
   currently met only by the **top-5 inline timeline** on Friend detail (Haldi 11) plus the
   **settlements-only** Settlement History (Haldi 24). The dedicated full
   expense+settlement, month-grouped, signed-amount log that Haldi screen 12 specifies is
   not built as a distinct screen. Build it (in Haldi) when the friends history surface is
   completed; the Haldi design already exists.
3. **Haldi 24 (covered, with a flagged divergence).** The Settlement History list itself is
   built and maps cleanly. The **reminder** element diverges: it is implemented as a
   one-tap "Remind" affordance on **Friend detail** (`friend_detail_screen.dart` →
   `reminders/`), whereas Haldi 24 places a pre-filled **compose** in Settlement History,
   and FR-SE-09 calls for a **free-text** reminder. This is a scope/placement reconcile for
   the PM (see §C item 6), not a new design commission.
4. **Haldi 26 (covered).** The OS lock-screen banner is system-rendered and not an app
   surface to design; the designable surfaces — the foreground in-app banner, the
   "Stay in the loop" pre-permission dialog, and the deep-link host — are all built.

### Addendum — built surfaces NOT among the 30 Haldi screens

These exist in `lib/**` but are outside the 30-screen handoff. They are the **built-not-yet-designed**
and **internal** rows (detailed with recommendations in §C).

| surface | app screen / FR | status |
|---|---|---|
| Change-phone OTP re-verification | `profile/presentation/change_phone_screen.dart` (FR-PR-02) | built-not-yet-designed |
| Orphaned auth placeholder | `auth/presentation/authenticated_screen.dart` (no FR; unreferenced) | internal — no design |
| Superseded profile stub | `profile/presentation/profile_placeholder_screen.dart` (no FR; superseded by Haldi 27) | internal — no design |
| Groups tab stub | `shell/presentation/groups_list_placeholder.dart` (no FR; replaced by Haldi 14) | internal — no design |
| 5-tab nav + persistent FAB chrome | `shell/presentation/authenticated_shell.dart` | covered by Haldi global navigation model |
| Photo source chooser | `profile/presentation/widgets/photo_picker_sheet.dart` | reuse Haldi global-overlay pattern |

---

## C. The "needs newly-commissioned design" list

Every current-or-required app surface that the 30-screen Haldi handoff does **not** cover,
each verified by reading the file, with a recommendation of **commission new Haldi design**
vs **reuse existing Haldi screen N** vs **internal — no design needed**.

1. **Change-phone OTP re-verification flow** — `profile/presentation/change_phone_screen.dart`
   (FR-PR-02). *Verified:* the screen is a real, two-OTP flow ("re-verify the CURRENT
   number, then verify the NEW number", switching body by `ChangePhoneStep`). *Why
   uncovered:* the Haldi handoff **locks `+91`** in Profile edit (screen 27 — "name + photo;
   +91 locked") and ships **no** change-number / re-verification screen anywhere in the 30.
   So a built P1 requirement has no Haldi target to convert to. → **Commission new Haldi
   design.** (It can lean heavily on the already-designed auth Phone-entry (3) and OTP (4)
   screens, but the two-step "verify current → verify new" chrome, intro/warning copy, and
   success state are new and must be specified.)

2. **Orphaned auth placeholder** — `auth/presentation/authenticated_screen.dart`. *Verified:*
   its own doc comment says "replaced by the profile setup flow in PR #8", and a repo-wide
   search finds **no reference** to `AuthenticatedScreen` anywhere in `lib/` (only its own
   file and the auth README). → **Internal — no design needed.** Recommend deletion as part
   of conversion cleanup; do not convert.

3. **Superseded profile stub** — `profile/presentation/profile_placeholder_screen.dart`.
   *Verified:* doc comment "Minimal Profile placeholder … will be replaced by the full
   Profile View/Edit (FR-PR-01)"; the full `profile_screen.dart` (= Haldi 27) now exists. →
   **Internal — no design needed.** Recommend deletion; the live surface is Haldi 27. Do not convert.

4. **Groups tab stub** — `shell/presentation/groups_list_placeholder.dart`. *Verified:*
   "`lib/features/groups/` is greenfield … this placeholder is the shell's stand-in"; the
   Groups directory contains no Dart files. → **Internal — no design needed.** It is
   **reuse Haldi screen 14** in effect: the Groups epic (now Sprint 4) deletes this file and
   mounts the real `GroupsListScreen` built straight in Haldi. Do not convert the stub.

5. **Photo source chooser** — `profile/presentation/widgets/photo_picker_sheet.dart`
   (camera/gallery overlay used by profile setup + edit). *Why partial:* Haldi designs the
   photo affordance on screens 5 and 27 but does not enumerate the source-chooser sheet. →
   **Reuse existing Haldi global-overlay pattern** ("design once, reuse" bottom sheet). Minor;
   no standalone commission.

6. **Reminder element** — `reminders/` + the "Remind" affordance on
   `friends/presentation/friend_detail_screen.dart` (FR-SE-09). *Why flagged:* Haldi designs
   a reminder **compose** inside Settlement History (screen 24); the build ships a **one-tap,
   fixed nudge** on Friend detail, and FR-SE-09 specifies **free-text**. → **Reuse existing
   Haldi screen 24/11**, but flag the placement/scope divergence to the PM for reconciliation.
   Not a new commission.

7. **Designed-not-yet-built Haldi screens** — Onboarding (2), Search (7), Friend history (12),
   Remove friend (13), Groups (14–20). *Why listed:* these are required but unbuilt; however
   the Haldi handoff **already designs** each one. → **Reuse existing Haldi screen N** (build
   them directly in Haldi in the later feature sprints — Groups in Sprint 4, the rest in
   Sprint 5/6). **No new design needed.**

**Net result:** exactly **one** surface needs a newly-commissioned Haldi design — the
**change-phone OTP re-verification flow (FR-PR-02)**. Three surfaces are internal throwaways
(no design; delete), and the remaining uncovered items reuse existing Haldi screens/overlays.

---

## D. Dependency note — what blocks Sprint 3 conversion

Sprint 3 (Design Conversion) reskins **already-built** screens onto Haldi. A built screen can
only be converted if it has a Haldi target to convert *to*. The dependency therefore lands
on exactly one item:

- **Blocked:** the **Profile & Settings conversion story** — specifically the
  `change_phone_screen.dart` sub-task — is **blocked until the new change-phone Haldi design
  lands** (§C item 1). The rest of that story (`profile_screen`, `edit_profile_screen`,
  `notification_preferences_screen`, `delete_account_screen`, contact-support) is **not**
  blocked; their Haldi targets (27, 28, 30, 29) already exist. **Recommendation:** commission
  the change-phone Haldi screen in the same window as "Sprint 3 PR #1 — design-token
  foundation" so the Profile-cluster conversion is not held; if it slips, convert the rest of
  the cluster and carry `change_phone` as a tracked follow-up.
- **Not blocked (delete, do not convert):** `authenticated_screen.dart`,
  `profile_placeholder_screen.dart`, `groups_list_placeholder.dart` — handled by the Phase 2
  conversion checklist as deletions; no design dependency.
- **Not a Sprint 3 dependency:** the designed-not-yet-built Haldi screens (2, 7, 12, 13,
  14–20) carry **no conversion dependency** because there is no built screen to convert — they
  are built fresh in Haldi in Sprint 4/5/6.
- **Flag (not a blocker):** the reminder placement/scope divergence (§C item 6) is a
  reconcile item for the PM, not a conversion blocker.

**Known design-vs-SRS conflict (not resolved here).** SRS §6.2 (Indigo Blue / Inter / Plus
Jakarta tokens) and §6.3 (the 11-screen "Core Screens" list) conflict with the Haldi handoff
(marigold `#E0922E` + ink `#2A211B`, Bricolage Grotesque + Hanken Grotesk, 30 screens). This
is expected and is resolved by the **PM's `update-srs` proposal**
(`docs/sprint-zero/srs-update-proposal-haldi.md`). I do **not** author that proposal; this
document only records the conflict so the PM can fold §6.2/§6.3 and the FR-PR-02 design gap
into it.

---

## E. Refusal / invariants check

Nothing in this coverage analysis weakens the four invariants: it is a visual/UX mapping that
touches no data path. **(1)** Money stays integer paise — rupee rendering remains
`formatInrFromPaise()` at the UI layer only; **(2)** `simplifiedBalances` stays
server-written / client-read-only — every mapped screen reads the projection and none is
asked to write it; **(3)** sharing stays OS system-share-sheet only — no per-channel buttons
are introduced; **(4)** single Firebase project, Emulator Suite for pre-merge testing —
unchanged. No new feature from SRS §12.3 is introduced.
